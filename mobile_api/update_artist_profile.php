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
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit();
}

$token = $_GET['token'] ?? '';
if (empty($token)) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Authentication token required']);
    exit();
}

try {
    require __DIR__ . '/../app/config/database.php';

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

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
        echo json_encode(['success' => false, 'message' => 'Invalid or expired token']);
        exit();
    }

    $userId = (int)$user['id'];
    $input = $_POST;

    if (!empty($input['username'])) {
        if (strlen($input['username']) < 4) {
            echo json_encode(['success' => false, 'message' => 'Username must be at least 4 characters']);
            exit();
        }

        $stmt = $pdo->prepare("
            SELECT id 
            FROM users 
            WHERE username = ? AND id != ?
        ");
        $stmt->execute([$input['username'], $userId]);

        if ($stmt->fetch()) {
            echo json_encode(['success' => false, 'message' => 'Username already taken']);
            exit();
        }

        $stmt = $pdo->prepare("UPDATE users SET username = ? WHERE id = ?");
        $stmt->execute([$input['username'], $userId]);
    }

    $stmt = $pdo->prepare("SELECT user_id FROM artist_profiles WHERE user_id = ?");
    $stmt->execute([$userId]);

    if (!$stmt->fetch()) {
        $pdo->prepare("
            INSERT INTO artist_profiles (user_id, created_at)
            VALUES (?, NOW())
        ")->execute([$userId]);
    }

    $allowedFields = [
        'business_name',
        'whatsapp_number',
        'instagram_handle',
        'facebook_page',
        'website_url',
        'location'
    ];

    $updateFields = [];
    $updateValues = [];

    foreach ($allowedFields as $field) {
        if (!empty($input[$field])) {

            // Basic validations
            if ($field === 'whatsapp_number' && !preg_match('/^[0-9]{10}$/', $input[$field])) {
                echo json_encode(['success' => false, 'message' => 'Invalid WhatsApp number']);
                exit();
            }

            if ($field === 'website_url' && !filter_var($input[$field], FILTER_VALIDATE_URL)) {
                echo json_encode(['success' => false, 'message' => 'Invalid website URL']);
                exit();
            }

            $updateFields[] = "$field = ?";
            $updateValues[] = trim($input[$field]);
        }
    }

    if (!empty($updateFields)) {
        $updateValues[] = $userId;
        $sql = "
            UPDATE artist_profiles 
            SET " . implode(', ', $updateFields) . ", updated_at = NOW()
            WHERE user_id = ?
        ";
        $stmt = $pdo->prepare($sql);
        $stmt->execute($updateValues);
    }

    $stmt = $pdo->prepare("
        SELECT 
            u.username,
            a.business_name,
            a.whatsapp_number,
            a.instagram_handle,
            a.facebook_page,
            a.website_url,
            a.location,
            a.artist_level,
            a.created_at,
            a.updated_at,
            u.status
        FROM users u
        JOIN artist_profiles a ON a.user_id = u.id
        WHERE u.id = ?
    ");
    $stmt->execute([$userId]);
    $profile = $stmt->fetch(PDO::FETCH_ASSOC);

    echo json_encode([
        'success' => true,
        'profile' => $profile
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to update profile',
        'error' => $e->getMessage()
    ]);
}
