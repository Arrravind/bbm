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

    // Validate user token
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

    // Fetch elite artists
    $stmt = $pdo->prepare("
        SELECT
            id,
            name,
            phone,
            email,
            specialization,
            experience_years,
            rating,
            location
        FROM elite_clients
        WHERE available = 1
        ORDER BY rating DESC, experience_years DESC
    ");

    $stmt->execute();

    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $artists = [];

    foreach ($rows as $row) {

        $artists[] = [
            'id' => (int)$row['id'],
            'name' => $row['name'] ?? 'Unknown Artist',
            'phone' => $row['phone'] ?? '',
            'email' => $row['email'] ?? '',
            'specialization' => $row['specialization'] ?? '',
            'experience_years' => (int)($row['experience_years'] ?? 0),
            'rating' => (float)($row['rating'] ?? 0),
            'location' => $row['location'] ?? ''
        ];
    }

    echo json_encode([
        'success' => true,
        'artists' => $artists
    ]);

} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([
        'error' => 'Failed to fetch artists: ' . $e->getMessage()
    ]);
}