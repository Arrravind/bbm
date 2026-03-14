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
    // Load BBM database config
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

    $userId = (int)$user['id'];

    // Fetch tutorial videos with access logic
    $stmt = $pdo->prepare("
        SELECT
            v.id,
            v.title,
            v.description,
            v.wistia_id,

            CASE
                WHEN ua.has_access = TRUE
                    AND (ua.expires_at IS NULL OR ua.expires_at > NOW())
                THEN TRUE
                ELSE FALSE
            END AS has_access

        FROM tutorial_videos v
        LEFT JOIN user_video_access ua
            ON ua.video_id = v.id
            AND ua.user_id = ?

        WHERE v.is_active = TRUE
        AND v.access_type <> 'free'

        ORDER BY v.created_at ASC
    ");

    $stmt->execute([$userId]);
    $videos = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Success response
    echo json_encode([
        'success' => true,
        'videos' => $videos
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Failed to fetch tutorial videos',
        'message' => $e->getMessage()
    ]);
}
