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

$token  = $_GET['token'] ?? '';
$screen = $_GET['screen'] ?? '';

if (empty($token)) {
    http_response_code(401);
    echo json_encode(['error' => 'Authentication token required']);
    exit();
}

if (empty($screen)) {
    http_response_code(400);
    echo json_encode(['error' => 'Screen parameter required']);
    exit();
}

try {

    // ============================
    // Load DB Config
    // ============================
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

    // ============================
    // Validate Token
    // ============================
    $stmt = $pdo->prepare("
        SELECT id 
        FROM users 
        WHERE api_token = ? 
          AND token_expires > NOW()
    ");
    $stmt->execute([$token]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired token']);
        exit();
    }

    // ============================
    // Fetch UI Config
    // ============================
    $stmt = $pdo->prepare("
        SELECT key_name, value
        FROM app_ui_config
        WHERE screen = ?
          AND status = 1
    ");
    $stmt->execute([$screen]);

    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $config = [];

    foreach ($rows as $row) {
        $config[$row['key_name']] = $row['value'];
    }

    echo json_encode([
        'success' => true,
        'config'  => $config
    ]);

} catch (Exception $e) {

    http_response_code(500);
    echo json_encode([
        'error' => 'Failed to fetch ui config: ' . $e->getMessage()
    ]);
}
