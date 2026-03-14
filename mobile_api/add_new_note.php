<?php

header('Content-Type: application/json');

include '../app/config/database.php';

try {

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME,
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $pdo->exec("SET time_zone = '+05:30'");

} catch (Exception $e) {

    echo json_encode([
        "success" => false,
        "error" => "DB connection failed"
    ]);

    exit;
}

$input = json_decode(file_get_contents("php://input"), true);

$token   = $input["token"] ?? "";
$lead_id = $input["lead_id"] ?? 0;
$note    = trim($input["note"] ?? "");
$status  = trim($input["status"] ?? "");

if (!$token || !$lead_id || (!$note && !$status)) {

    echo json_encode([
        "success" => false,
        "error" => "Note or status required"
    ]);

    exit;
}

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

    echo json_encode([
        "success" => false,
        "error" => "Invalid token"
    ]);

    exit;
}

$user_id = (int)$user["id"];
$role    = $user["role"] ?? "";

try {

    $pdo->beginTransaction();

    // TELECALLER WORKFLOW

    if ($role === "telecaller") {

    // get tracking id
    $stmt = $pdo->prepare("
        SELECT tracking_id
        FROM team_lead_tracking
        WHERE lead_id = ?
        LIMIT 1
    ");

    $stmt->execute([$lead_id]);
    $tracking_id = $stmt->fetchColumn();

    // get service type
    $stmt = $pdo->prepare("
        SELECT services_required
        FROM leads
        WHERE id = ?
        LIMIT 1
    ");
    $stmt->execute([$lead_id]);

    $service_type = $stmt->fetchColumn() ?: '';

    // get status id
    $status_id = null;

    if ($status) {

        $stmt = $pdo->prepare("
            SELECT status_id
            FROM status_master
            WHERE status_name = ?
            LIMIT 1
        ");

        $stmt->execute([$status]);
        $status_id = $stmt->fetchColumn();
    }

    // create tracking record if not exists
    if (!$tracking_id) {

        $stmt = $pdo->prepare("
            INSERT INTO team_lead_tracking
            (lead_id, created_by, team_member_id, service_type, current_status_id)
            VALUES (?, ?, ?, ?, ?)
        ");

        $stmt->execute([
            $lead_id,
            $user_id,
            $user_id,
            $service_type,
            $status_id
        ]);

        $tracking_id = $pdo->lastInsertId();

    } else {

            $stmt = $pdo->prepare("
                UPDATE team_lead_tracking
                SET last_updated_by = ?, updated_at = NOW(), team_member_id = ?
                WHERE tracking_id = ?
            ");
            $stmt->execute([$user_id, $user_id, $tracking_id]);

            // update status in tracking table
            if ($status_id) {

                $stmt = $pdo->prepare("
                    UPDATE team_lead_tracking
                    SET current_status_id = ?
                    WHERE tracking_id = ?
                ");

                $stmt->execute([
                    $status_id,                   
                    $tracking_id
                ]);
            }
        }

        $activity_type = 'note';

        if ($status && $note) {
            $activity_type = 'call';
        } elseif ($status) {
            $activity_type = 'telecaller_status';
        } elseif ($note) {
            $activity_type = 'note';
        }

        // insert activity 
        $stmt = $pdo->prepare("
            INSERT INTO lead_activity
            (tracking_id, activity_type, performed_by, status_id, activity_notes, created_at)
            VALUES (?, ?, ?, ?, ?, NOW())
        ");

        $stmt->execute([
            $tracking_id,
            $activity_type,
            $user_id,
            $status_id,
            $note
        ]);
    }

    // NORMAL ARTIST WORKFLOW

    else {

        $stmt = $pdo->prepare("
            INSERT INTO lead_notes
            (lead_id, user_id, note, status)
            VALUES (?, ?, ?, ?)
        ");

        $stmt->execute([
            $lead_id,
            $user_id,
            $note,
            $status
        ]);
    }

    $pdo->commit();

    echo json_encode([
        "success" => true
    ]);

} catch (Exception $e) {

    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    echo json_encode([
        "success" => false,
        "error" => $e->getMessage()
    ]);
}