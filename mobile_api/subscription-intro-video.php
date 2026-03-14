<?php

// Set JSON headers first
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

// Get JSON input
$input = file_get_contents('php://input');
$data = json_decode($input, true);

if (!$data) {
    $data = $_POST;
}

$token = $data['token'] ?? '';

if (empty($token)) {
    http_response_code(401);
    echo json_encode(['error' => 'Token required']);
    exit();
}

try {
    // Load DB config
    $config_file = __DIR__ . '/../app/config/database.php';

    if (!file_exists($config_file)) {
        throw new Exception('Database config not found');
    }

    include $config_file;

    // Create PDO connection
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    // Validate token (only authentication, nothing else)
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

    // 🔹 FETCH FREE VIDEO ONLY
    $stmt = $pdo->prepare("
        SELECT
            id,
            title,
            description,
            wistia_id
        FROM tutorial_videos
        WHERE is_active = 1
          AND access_type = 'free'
        ORDER BY created_at ASC
        LIMIT 1
    ");

    $stmt->execute();
    $video = $stmt->fetch(PDO::FETCH_ASSOC);

    echo json_encode([
        'success' => true,
        'video' => $video ?: null
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Failed to fetch video',
        'message' => $e->getMessage()
    ]);
}
