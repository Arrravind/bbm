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

    // Validate Token

    $stmt = $pdo->prepare("
        SELECT id, role
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

    // TOTAL LEADS CONTACTED

    $stmt = $pdo->prepare("
        SELECT COUNT(DISTINCT tracking_id)
        FROM lead_activity
        WHERE performed_by = ?
    ");

    $stmt->execute([$userId]);
    $total_contacted = (int)$stmt->fetchColumn();

    // CALLS TODAY

    $stmt = $pdo->prepare("
        SELECT COUNT(*)
        FROM lead_activity
        WHERE performed_by = ?
        AND activity_type = 'call'
        AND DATE(created_at) = CURDATE()
    ");

    $stmt->execute([$userId]);
    $calls_today = (int)$stmt->fetchColumn();

    // NOTES ADDED

    $stmt = $pdo->prepare("
        SELECT COUNT(*)
        FROM lead_activity
        WHERE performed_by = ?
        AND activity_type = 'note'
    ");

    $stmt->execute([$userId]);
    $notes_added = (int)$stmt->fetchColumn();

    // INTERESTED LEADS

    $stmt = $pdo->prepare("
        SELECT COUNT(DISTINCT la.tracking_id)
        FROM lead_activity la
        JOIN status_master sm ON sm.status_id = la.status_id
        WHERE la.performed_by = ?
        AND sm.status_name = 'interested'
    ");

    $stmt->execute([$userId]);
    $interested_leads = (int)$stmt->fetchColumn();

    // FOLLOWUPS

    $stmt = $pdo->prepare("
        SELECT COUNT(*)
        FROM lead_activity
        WHERE performed_by = ?
        AND follow_up_date >= CURDATE()
    ");

    $stmt->execute([$userId]);
    $followups = (int)$stmt->fetchColumn();

    // RECENT ACTIVITY

    $stmt = $pdo->prepare("
        SELECT 
            la.tracking_id,
            la.activity_type,
            sm.status_name,
            la.activity_notes,
            la.created_at,
            l.customer_name,
            l.event_date
        FROM lead_activity la
        LEFT JOIN status_master sm ON sm.status_id = la.status_id
        JOIN leads l ON l.id = la.tracking_id
        WHERE la.performed_by = ?
        ORDER BY la.created_at DESC
        LIMIT 10
    ");

    $stmt->execute([$userId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $recent_activity = [];

    foreach ($rows as $row) {

        $recent_activity[] = [
            'id'            => (int)$row['tracking_id'],
            'customer_name' => $row['customer_name'] ?: 'Unknown',
            'event_date'    => $row['event_date'] ?: '',
            'activity_type' => $row['activity_type'] ?: '',
            'status'        => $row['status_name'] ?: '',
            'note'          => $row['note'] ?: '',
            'created_at'    => $row['created_at']
        ];
    }

    // FINAL RESPONSE

    echo json_encode([
        'success' => true,

        'total_contacted' => $total_contacted,
        'calls_today' => $calls_today,
        'notes_added' => $notes_added,
        'interested_leads' => $interested_leads,
        'followups' => $followups,

        'recent_activity' => $recent_activity
    ]);

} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([
        'error' => 'Failed to fetch telecaller stats: ' . $e->getMessage()
    ]);
}