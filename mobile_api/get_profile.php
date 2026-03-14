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
    http_response_code(401);
    echo json_encode(['error' => 'Authentication token required']);
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

    // Validate token from users table
    $stmt = $pdo->prepare("SELECT id FROM users WHERE api_token = ? AND token_expires > NOW()");
    $stmt->execute([$token]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired token']);
        exit();
    }

    $userId = (int)$user['id'];

    // Fetch artist profile linked to this user
    $stmt = $pdo->prepare("SELECT * FROM artist_profiles WHERE user_id = ?");
    $stmt->execute([$userId]);
    $artist = $stmt->fetch(PDO::FETCH_ASSOC);
    
    $stmt2 = $pdo->prepare("SELECT * FROM users WHERE id = ?");
    $stmt2->execute([$userId]);
    $artist_un = $stmt2->fetch(PDO::FETCH_ASSOC);

    if (!$artist) {
        echo json_encode([
            'success' => false,
            'message' => 'No artist profile found for this user'
        ]);
        exit();
    }

    if ($artist['is_active'] == 0){
        $status = 'Inactive';
    } else {
        $status = 'Active';
    }

    echo json_encode([
        'success' => true,
        'profile' => [
            'id'              => (int)$artist['user_id'],
            'username'        => $artist_un['username'] ?? '',
            'business_name'   => $artist['business_name'] ?? '',
            'artist_level'    => $artist['artist_level'] ?? '',
            'location'        => $artist['location'] ?? '',
            'status'        => $status,
            'whatsapp_number' => $artist['whatsapp_number'] ?? '',
            'instagram_handle'=> $artist['instagram_handle'] ?? '',
            'facebook_page'   => $artist['facebook_page'] ?? '',
            'website_url'     => $artist['website_url'] ?? '',
            'created_at'      => $artist['created_at'] ?? '',
            'updated_at'      => $artist['updated_at'] ?? ''
        ]
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to fetch artist profile: ' . $e->getMessage()]);
}
