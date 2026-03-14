<?php

// Set JSON headers
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

$leadId = $data['lead_id'] ?? '';
$token  = $data['token'] ?? '';

if (empty($leadId) || empty($token)) {
    http_response_code(400);
    echo json_encode(['error' => 'Lead ID and token required']);
    exit();
}

try {
    // Load DB config
    $config_file = __DIR__ . '/../app/config/database.php';
    if (!file_exists($config_file)) {
        throw new Exception('Database config not found');
    }
    include $config_file;

    // Connect PDO
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    // Fetch claim_lock_duration_hours from system_settings (for future logic)
    $stmt = $pdo->prepare("SELECT setting_value FROM system_settings WHERE setting_key = 'claim_lock_duration_hours' LIMIT 1");
    $stmt->execute();
    $claimLockDurationHours = (int)($stmt->fetchColumn() ?: 48);

    // Validate token
    $stmt = $pdo->prepare("SELECT * FROM users WHERE api_token = ? AND token_expires > NOW() AND status = 'active'");
    $stmt->execute([$token]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired token']);
        exit();
    }

    // Check if lead exists and is claimed by this user
    $stmt = $pdo->prepare("SELECT * FROM leads WHERE id = ? AND claimed_by = ?");
    $stmt->execute([$leadId, $user['id']]);
    $lead = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$lead) {
        http_response_code(404);
        echo json_encode(['error' => 'Lead not found or not claimed by you']);
        exit();
    }

    // Release the lead
    $stmt = $pdo->prepare("
        UPDATE leads
        SET claimed_by = NULL, claim_time = NULL, claim_expiry = NULL
        WHERE id = ? AND claimed_by = ?
    ");
    $stmt->execute([$leadId, $user['id']]);

    echo json_encode([
        'success' => true,
        'message' => 'Lead released successfully',
        'lead_id' => (int)$leadId
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to release lead: ' . $e->getMessage()]);
}
?>
