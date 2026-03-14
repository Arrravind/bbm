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

$username = $data['username'] ?? '';
$password = $data['password'] ?? '';

if (empty($username) || empty($password)) {
    http_response_code(400);
    echo json_encode(['error' => 'Username and password required']);
    exit();
}

try {
    // Direct database connection using BBM's config
    $config_file = __DIR__ . '/../app/config/database.php';
    
    if (!file_exists($config_file)) {
        throw new Exception('Database config not found');
    }
    
    include $config_file;
    
    // Create PDO connection directly
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    // Check user credentials
    $stmt = $pdo->prepare("
        SELECT u.*, ap.business_name
        FROM users u
        LEFT JOIN artist_profiles ap ON ap.user_id = u.id
        WHERE u.username = ?
    ");
    $stmt->execute([$username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($user && password_verify($password, $user['password_hash'])) {
        // Generate simple token
        $token = base64_encode($user['id'] . ':' . time() . ':' . md5($user['username']));
        
        // Store token in database
        $stmt = $pdo->prepare("UPDATE users SET api_token = ?, token_expires = DATE_ADD(NOW(), INTERVAL 30 DAY) WHERE id = ?");
        $stmt->execute([$token, $user['id']]);
        
        // Return success response
        echo json_encode([
            'success' => true,
            'token' => $token,
            'user' => [
                'id' => (int)$user['id'],
                'username' => $user['username'],
                'email' => $user['email'],
                'role' => $user['role'],
                'status' => $user['status'],
                'level' => (int)$user['level'],
                'business_name' => $user['business_name'] ?? ''
            ]
        ]);
    } else {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid credentials']);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Authentication failed: ' . $e->getMessage()]);
}
?>
