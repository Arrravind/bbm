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
$leadId = isset($_GET['lead_id']) ? (int)$_GET['lead_id'] : 0;

if (empty($token) || $leadId <= 0) {
    http_response_code(400);
    echo json_encode(['error' => 'Token and lead_id are required']);
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

    $pdo->exec("SET time_zone = '+05:30'");

    // Validate token and get role
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

    $user_id = (int)$user['id'];
    $role    = $user['role'];

    // Fetch lead details 
    $stmt = $pdo->prepare("
        SELECT 
            id,
            customer_name,
            whatsapp_number AS phone,
            email,
            event_date,
            event_type,
            location AS venue,
            budget_range AS budget,
            additional_info AS requirements,
            status,
            created_at,
            updated_at,
            claim_time,
            claim_expiry,
            claimed_by,
            is_locked
        FROM leads
        WHERE id = ?
        LIMIT 1
    ");

    $stmt->execute([$leadId]);
    $lead = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$lead) {
        http_response_code(404);
        echo json_encode(['error' => 'Lead not found']);
        exit();
    }

    // TELECALLER NOTES

    if ($role === 'telecaller') {

        $stmt = $pdo->prepare("
            SELECT 
                t.tracking_id,
                sm.status_name
            FROM team_lead_tracking t
            LEFT JOIN status_master sm
            ON t.current_status_id = sm.status_id
            WHERE t.lead_id = ?
            LIMIT 1
        ");

        $stmt->execute([$leadId]);
        $tracking = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($tracking) {

            $tracking_id = $tracking['tracking_id'];

            // override main status
            if (!empty($tracking['status_name'])) {
                $lead['status'] = $tracking['status_name'];
            }

            // fetch notes
            $stmt = $pdo->prepare("
                SELECT 
                    la.activity_notes AS note,
                    sm.status_name AS status,
                    la.created_at
                FROM lead_activity la
                LEFT JOIN status_master sm
                ON la.status_id = sm.status_id
                WHERE la.tracking_id = ?                
                ORDER BY la.created_at DESC
                ");

                $stmt->execute([$tracking_id]);

                $notes = $stmt->fetchAll(PDO::FETCH_ASSOC);

            } else {
                $notes = [];
            }

    }

    // ARTIST NOTES 

    else {

        $stmt = $pdo->prepare("
            SELECT note, status, created_at
            FROM lead_notes
            WHERE lead_id = ? AND user_id = ?
            ORDER BY created_at DESC
        ");

        $stmt->execute([$leadId, $user_id]);

        $notes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    $lead["notes"] = $notes;

    // Determine if released 
    $isReleased = 0;

    if ((int)$lead['claimed_by'] !== (int)$user_id) {
        $isReleased = 1;
    } elseif ((int)$lead['is_locked'] === 0) {
        $isReleased = 1;
    } elseif ($lead['claim_expiry'] !== null && strtotime($lead['claim_expiry']) < time()) {
        $isReleased = 1;
    }

    // Normalize event_type 
    $eventTypeRaw = $lead['event_type'] ?? '';
    $eventType = '';

    if (is_array($eventTypeRaw)) {
        $eventType = implode(', ', $eventTypeRaw);
    } else {
        $decoded = json_decode($eventTypeRaw, true);

        if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
            $eventType = implode(', ', $decoded);
        } else {
            $eventType = $eventTypeRaw;
        }
    }

    // Normalize requirements 
    $requirementsRaw = $lead['requirements'] ?? '';
    $decodedReq = json_decode($requirementsRaw, true);

    if (
        json_last_error() === JSON_ERROR_NONE &&
        is_array($decodedReq)
    ) {
        $requirements = 'N/A';
    } else {
        $requirements = trim($requirementsRaw) !== ''
            ? $requirementsRaw
            : 'N/A';
    }

    echo json_encode([
        'success' => true,
        'lead' => [
            'id'           => (int)$lead['id'],
            'customer_name'=> $lead['customer_name'] ?? 'Unknown',
            'phone'        => $lead['phone'] ?? 'N/A',
            'email'        => $lead['email'] ?? 'N/A',
            'event_date'   => $lead['event_date'] ?? '',
            'event_type'   => $eventType ?: 'N/A',
            'venue'        => $lead['venue'] ?? 'N/A',
            'guest_count'  => null,
            'budget'       => $lead['budget'] ?? 'N/A',
            'requirements' => $requirements,
            'status'       => $lead['status'] ?? 'new',
            'created_at'   => $lead['created_at'] ?? '',
            'updated_at'   => $lead['updated_at'] ?? '',
            'released'     => $isReleased,
            'claim_time'   => $lead['claim_time'] ?? '',
            'notes'        => $lead['notes'] ?? []
        ]
    ]);

} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([
        'error' => 'Failed to fetch lead details: ' . $e->getMessage()
    ]);
}
?>