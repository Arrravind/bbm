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
    echo json_encode(['error' => 'Method not allowed']);
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

    $stmt = $pdo->prepare("
        SELECT setting_value
        FROM system_settings
        WHERE setting_key = 'auto_release_inactive_hours'
        LIMIT 1
    ");
    $stmt->execute();

    $autoReleaseInactiveHours = (int)($stmt->fetchColumn() ?: 48);

} catch (Exception $e) {

    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed']);
    exit();
}

$input = json_decode(file_get_contents('php://input'), true);

if (!$input) {
    $input = $_POST;
}

$token      = $input['token'] ?? '';
$lead_id    = isset($input['lead_id']) ? intval($input['lead_id']) : 0;
$new_status = strtolower(trim($input['status'] ?? ''));
$notes      = trim($input['notes'] ?? '');

if (empty($token) || empty($lead_id) || empty($new_status)) {

    http_response_code(400);
    echo json_encode(['error' => 'Missing required fields']);
    exit();
}

try {

    // Validate user and get role
    $stmt = $pdo->prepare("
        SELECT id, role
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

    $user_id = (int)$user['id'];
    $role    = $user['role'];

    // TELECALLER WORKFLOW

    if ($role === 'telecaller') {

        $pdo->beginTransaction();

        $stmt = $pdo->prepare("SELECT id FROM leads WHERE id = ? LIMIT 1");
        $stmt->execute([$lead_id]);

        if (!$stmt->fetch()) {
            $pdo->rollBack();
            http_response_code(404);
            echo json_encode(['error' => 'Lead not found']);
            exit();
        }

        // get status id
        $stmt = $pdo->prepare("
            SELECT status_id
            FROM status_master
            WHERE status_name = ?
            LIMIT 1
        ");
        $stmt->execute([$new_status]);
        $status_id = $stmt->fetchColumn();

        if (!$status_id) {

            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['error' => 'Invalid status']);
            exit();
        }

        $stmt = $pdo->prepare("
            SELECT services_required
            FROM leads
            WHERE id = ?
            LIMIT 1
        ");
        $stmt->execute([$lead_id]);

        $service_type = $stmt->fetchColumn() ?: '';

        // get tracking id
        $stmt = $pdo->prepare("
            SELECT tracking_id
            FROM team_lead_tracking
            WHERE lead_id = ?
            LIMIT 1
        ");
        $stmt->execute([$lead_id]);
        $tracking_id = $stmt->fetchColumn();

        if (!$tracking_id) {

            $stmt = $pdo->prepare("
                INSERT INTO team_lead_tracking
                (
                    lead_id,
                    service_type,
                    team_member_id,
                    created_by,
                    current_status_id,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, NOW())
            ");

            $stmt->execute([
                $lead_id,
                $service_type,
                $user_id,
                $user_id,
                $status_id
            ]);

            $tracking_id = $pdo->lastInsertId();

        } else {

            $stmt = $pdo->prepare("
                UPDATE team_lead_tracking
                SET current_status_id = ?, last_updated_by = ?, updated_at = NOW()
                WHERE tracking_id = ?
            ");

            $stmt->execute([
                $status_id,
                $user_id,
                $tracking_id
            ]);
        }

        // insert activity
        $stmt = $pdo->prepare("
            INSERT INTO lead_activity
            (tracking_id, activity_type, performed_by, status_id, activity_notes, created_at)
            VALUES (?, 'telecaller_status', ?, ?, ?, NOW())
        ");

        $stmt->execute([
            $tracking_id,
            $user_id,
            $status_id,
            $notes
        ]);

        $pdo->commit();

        echo json_encode([
            'success' => true,
            'message' => 'Telecaller status updated',
            'lead_id' => $lead_id,
            'status' => $new_status
        ]);

        exit();
    }

    // ARTIST WORKFLOW 

    $valid_statuses = ['new', 'contacted', 'booked', 'closed'];

    if (!in_array($new_status, $valid_statuses)) {

        http_response_code(400);
        echo json_encode(['error' => 'Invalid status']);
        exit();
    }

    $stmt = $pdo->prepare("SELECT * FROM leads WHERE id = ?");
    $stmt->execute([$lead_id]);

    $lead = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$lead) {

        http_response_code(404);
        echo json_encode(['error' => 'Lead not found']);
        exit();
    }

    $isOwner = false;

    if ($lead['claimed_by'] == $user_id) {
        $isOwner = true;
    } else {

        $stmt = $pdo->prepare("
            SELECT COUNT(*)
            FROM claimed_leads_log
            WHERE lead_id = ?
            AND user_id = ?
        ");

        $stmt->execute([$lead_id, $user_id]);

        if ($stmt->fetchColumn() > 0) {
            $isOwner = true;
        }
    }

    if (!$isOwner) {

        http_response_code(403);
        echo json_encode([
            'error' => 'You are not authorized to update this lead (not current or previous owner)'
        ]);

        exit();
    }

    $old_status = $lead['status'];

    $lock_permanent = in_array($new_status, ['booked', 'closed']);
    $claim_expiry   = $lock_permanent ? null : $lead['claim_expiry'];

    $stmt = $pdo->prepare("
        UPDATE leads
        SET status = ?, claim_expiry = ?
        WHERE id = ?
    ");

    $stmt->execute([
        $new_status,
        $claim_expiry,
        $lead_id
    ]);

    $stmt = $pdo->prepare("
        INSERT INTO lead_status_history
        (lead_id, old_status, new_status, changed_by, notes, changed_at)
        VALUES (?, ?, ?, ?, ?, NOW())
    ");

    $stmt->execute([
        $lead_id,
        $old_status,
        $new_status,
        $user_id,
        $notes
    ]);

    echo json_encode([
        'success' => true,
        'message' => "Lead Status updated from $old_status to $new_status",
        'lead_id' => $lead_id,
        'old_status' => $old_status,
        'new_status' => $new_status,
        'permanent_lock' => $lock_permanent
    ]);

} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([
        'error' => 'Server error: ' . $e->getMessage()
    ]);
}
?>