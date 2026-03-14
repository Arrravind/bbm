<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit();
}

try {

    require __DIR__ . '/../app/config/database.php';

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $input = json_decode(file_get_contents("php://input"), true);

    $mobile = $input['mobile'] ?? '';

    if (empty($mobile)) {
        echo json_encode([
            'success' => false,
            'message' => 'Mobile number required'
        ]);
        exit();
    }

    if (!preg_match('/^[0-9]{10}$/', $mobile)) {
        echo json_encode([
            'success' => false,
            'message' => 'Invalid mobile number'
        ]);
        exit();
    }

    $stmt = $pdo->prepare("
        SELECT user_id
        FROM artist_profiles
        WHERE whatsapp_number = ?
    ");
    $stmt->execute([$mobile]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        echo json_encode([
            'success' => false,
            'message' => 'Mobile number not registered'
        ]);
        exit();
    }

    $otp = rand(100000, 999999);

    $stmt = $pdo->prepare("
        INSERT INTO password_resets (mobile, otp, expires_at)
        VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 5 MINUTE))
    ");
    $stmt->execute([$mobile, $otp]);

    echo json_encode([
        'success' => true,
        'message' => 'OTP sent successfully',
        'otp' => $otp   // remove later in production
    ]);

} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([
        'success' => false,
        'message' => 'Server error',
        'error' => $e->getMessage()
    ]);
}