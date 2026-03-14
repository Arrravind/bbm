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
$artist_id  = isset($input['artist_id']) ? intval($input['artist_id']) : 0;

if (empty($token) || empty($lead_id) || empty($artist_id)) {

    http_response_code(400);
    echo json_encode(['error' => 'Missing required fields']);
    exit();
}


try {

    // Validate telecaller
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

    if ($user['role'] !== 'telecaller') {

        http_response_code(403);
        echo json_encode(['error' => 'Only telecallers can assign artists']);
        exit();
    }

    $telecaller_id = (int)$user['id'];



    // Check lead exists
    $stmt = $pdo->prepare("
        SELECT id, services_required
        FROM leads
        WHERE id = ?
        LIMIT 1
    ");

    $stmt->execute([$lead_id]);

    $lead = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$lead) {

        http_response_code(404);
        echo json_encode(['error' => 'Lead not found']);
        exit();
    }



    // Check artist exists (elite artist table)
    $stmt = $pdo->prepare("
        SELECT id, name
        FROM elite_clients
        WHERE id = ?
        LIMIT 1
    ");

    $stmt->execute([$artist_id]);

    $artist = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$artist) {

        http_response_code(404);
        echo json_encode(['error' => 'Artist not found']);
        exit();
    }



    $pdo->beginTransaction();



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
                assigned_artist_id,
                created_by,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, NOW())
        ");

        $stmt->execute([
            $lead_id,
            $lead['services_required'],
            $telecaller_id,
            $artist_id,
            $telecaller_id
        ]);

        $tracking_id = $pdo->lastInsertId();

    } else {

        $stmt = $pdo->prepare("
            UPDATE team_lead_tracking
            SET assigned_artist_id = ?,
                last_updated_by = ?,
                updated_at = NOW(),
                team_member_id = ?
            WHERE tracking_id = ?
        ");

        $stmt->execute([
            $artist_id,
            $telecaller_id,
            $telecaller_id,
            $tracking_id
        ]);
    }

    // log activity
    $note = "Artist assigned: " . $artist['name'];

    $stmt = $pdo->prepare("
        INSERT INTO lead_activity
        (
            tracking_id,
            activity_type,
            performed_by,
            related_artist_id,
            activity_notes,
            created_at
        )
        VALUES (?, 'artist_assignment', ?, ?, ?, NOW())
    ");

    $stmt->execute([
        $tracking_id,
        $telecaller_id,
        $artist_id,
        $note
    ]);

    $pdo->commit();



    echo json_encode([
        'success' => true,
        'message' => 'Artist assigned successfully',
        'lead_id' => $lead_id,
        'artist_id' => $artist_id,
        'artist_name' => $artist['name']
    ]);

} catch (Exception $e) {

    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    http_response_code(500);

    echo json_encode([
        'error' => 'Server error: ' . $e->getMessage()
    ]);
}
?>