<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

try {
    // Load DB config
    $config_file = __DIR__ . '/../app/config/database.php';
    if (!file_exists($config_file)) {
        throw new Exception('Database config not found');
    }
    include $config_file;

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $pdo->exec("SET time_zone = '+05:30'");

    // Parse JSON input
    $data = json_decode(file_get_contents('php://input'), true);
    $apiToken = $data['api_token'] ?? '';
    $fcmToken = $data['fcm_token'] ?? '';

    if (empty($apiToken)) {
        http_response_code(401);
        echo json_encode(['error' => 'Authentication token required']);
        exit();
    }

    if (empty($fcmToken)) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing FCM token']);
        exit();
    }

    // Validate the user's API token
    $stmt = $pdo->prepare("SELECT id FROM users WHERE api_token = ? AND token_expires > NOW()");
    $stmt->execute([$apiToken]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired token']);
        exit();
    }

    $userId = (int)$user['id'];

    // Update user's FCM token
    $stmt = $pdo->prepare("UPDATE users SET fcm_token = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?");
    $stmt->execute([$fcmToken, $userId]);

    echo json_encode([
        'success' => true,
        'message' => 'FCM token updated successfully',
        'user_id' => $userId
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to update FCM token: ' . $e->getMessage()]);
}
