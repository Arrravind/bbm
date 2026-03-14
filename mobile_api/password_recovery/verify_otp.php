<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

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
    $otp = $input['otp'] ?? '';

    $stmt = $pdo->prepare("
        SELECT id
        FROM password_resets
        WHERE mobile = ?
        AND otp = ?
        AND expires_at > NOW()
        ORDER BY id DESC
        LIMIT 1
    ");

    $stmt->execute([$mobile, $otp]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        echo json_encode([
            'success' => false,
            'message' => 'Invalid or expired OTP'
        ]);
        exit();
    }

    echo json_encode([
        'success' => true,
        'message' => 'OTP verified'
    ]);

} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([
        'success' => false,
        'message' => 'Server error',
        'error' => $e->getMessage()
    ]);
}