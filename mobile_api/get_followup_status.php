<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

$token = $_GET['token'] ?? '';

if (empty($token)) {
    http_response_code(400);
    echo json_encode(['error' => 'Token is required']);
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
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
        ]
    );

    $pdo->exec("SET time_zone = '+05:30'");

    // Validate token
    $stmt = $pdo->prepare("
        SELECT id
        FROM users
        WHERE api_token = ?
        AND token_expires > NOW()
        LIMIT 1
    ");

    $stmt->execute([$token]);

    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired token']);
        exit();
    }

    // Fetch followup statuses
    $stmt = $pdo->prepare("
        SELECT value
        FROM app_ui_config
        WHERE screen = 'lead_details'
        AND key_name = 'followup_status'
        AND status = 1
        ORDER BY id ASC
    ");

    $stmt->execute();

    $statuses = [];

    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $statuses[] = $row['value'];
    }

    echo json_encode([
        'success' => true,
        'statuses' => $statuses
    ]);

} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([
        'error' => 'Failed to fetch followup statuses: ' . $e->getMessage()
    ]);

}
