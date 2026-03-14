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
    $password = $input['password'] ?? '';

    if (strlen($password) < 6) {
        echo json_encode([
            'success' => false,
            'message' => 'Password too short'
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
            'message' => 'User not found'
        ]);
        exit();
    }

    $userId = $user['user_id'];

    $hash = password_hash($password, PASSWORD_DEFAULT);

    $stmt = $pdo->prepare("
        UPDATE users
        SET password = ?
        WHERE id = ?
    ");

    $stmt->execute([$hash, $userId]);

    echo json_encode([
        'success' => true,
        'message' => 'Password updated successfully'
    ]);

} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([
        'success' => false,
        'message' => 'Server error',
        'error' => $e->getMessage()
    ]);
}