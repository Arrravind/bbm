<?php

// === JSON headers ===
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

try {
    // === STEP 1: Connect to DB ===
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

    // === STEP 2: Ensure `notified` column exists ===
    $colCheck = $pdo->query("SHOW COLUMNS FROM leads LIKE 'notified'");
    if ($colCheck->rowCount() == 0) {
        $pdo->exec("ALTER TABLE leads ADD COLUMN notified TINYINT(1) DEFAULT 0");
        // Mark existing leads as already notified so we don't spam old ones
        $pdo->exec("UPDATE leads SET notified = 1");
        $pdo->exec("ALTER TABLE leads ALTER COLUMN notified SET DEFAULT 0");
    }

    // === STEP 3: Atomically select and lock up to 5 unnotified leads ===
    $pdo->beginTransaction();

    try {
        $stmt = $pdo->prepare("
            SELECT id, customer_name, services_required
            FROM leads
            WHERE notified = 0
            ORDER BY id DESC
            LIMIT 5
            FOR UPDATE
        ");
        $stmt->execute();
        $leadsToNotify = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if (empty($leadsToNotify)) {
            $pdo->rollBack();
            echo json_encode(['success' => true, 'message' => 'No new leads found']);
            exit();
        }

        // Mark these leads as notified
        $leadIds = array_column($leadsToNotify, 'id');
        $placeholders = implode(',', array_fill(0, count($leadIds), '?'));
        $updateStmt = $pdo->prepare("UPDATE leads SET notified = 1 WHERE id IN ($placeholders)");
        $updateStmt->execute($leadIds);

        $pdo->commit();

    } catch (Exception $e) {
        $pdo->rollBack();
        throw $e;
    }

    $sent = [];

    foreach ($leadsToNotify as $lead) {
        $leadName = sanitize_input($lead['customer_name']);

        // Parse services from JSON array
        $services = [];
        if (!empty($lead['services_required'])) {
            $servicesData = json_decode($lead['services_required'], true);
            if (is_array($servicesData)) {
                $services = array_map('sanitize_input', $servicesData);
            }
        }

        // Format services for notification
        $servicesText = !empty($services) ? implode(', ', $services) : 'Makeup services';

        $title = "💄 New Lead Available!";
        $body = "$leadName is interested in $servicesText.";

        // === STEP 5: Send notification ===
        $sendScriptPath = __DIR__ . '/send_fcm.php';
        if (!file_exists($sendScriptPath)) {
            throw new Exception('send_fcm.php not found');
        }

        $ch = curl_init("https://bbm.lokiwebvibe.com/mobile_api/send_fcm.php");
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => http_build_query([
                'title' => $title,
                'body'  => $body
            ]),
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $sent[] = [
            'lead_id'   => $lead['id'],
            'title'     => $title,
            'body'      => $body,
            'sent_at'   => date('Y-m-d H:i:s'),
            'http_code' => $httpCode,
            'response'  => json_decode($response, true)
        ];
    }

    // === STEP 6: Final response ===
    echo json_encode([
        'success' => true,
        'message' => 'New leads processed (notifications sent)',
        'results' => $sent,
        'total_processed' => count($sent)
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}

// === Helper: Sanitize Input ===
function sanitize_input($data) {
    return htmlspecialchars(trim($data), ENT_QUOTES, 'UTF-8');
}
?>
