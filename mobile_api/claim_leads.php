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

$data = json_decode(file_get_contents('php://input'), true);
if (!$data) $data = $_POST;

$leadId = isset($data['lead_id']) ? intval($data['lead_id']) : 0;
$token  = $data['token'] ?? '';

if (empty($leadId) || empty($token)) {
    http_response_code(400);
    echo json_encode(['error' => 'Lead ID and token required']);
    exit();
}

try {
    // Database config
    include __DIR__ . '/../app/config/database.php';

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $pdo->exec("SET time_zone = '+05:30'");

    // Validate user token
    $stmt = $pdo->prepare("
        SELECT id, level
        FROM users
        WHERE api_token = ?
          AND token_expires > NOW()
          AND status = 'active'
        LIMIT 1
    ");
    $stmt->execute([$token]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired token']);
        exit();
    }

    $userId    = (int)$user['id'];
    $userLevel = (int)$user['level'];

    // Fetch active subscription
    $stmt = $pdo->prepare("
        SELECT id, total_leads_claimed, end_date
        FROM subscription_history
        WHERE user_id = ?
          AND status = 'active'
        LIMIT 1
    ");
    $stmt->execute([$userId]);
    $subscription = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$subscription) {
        http_response_code(403);
        echo json_encode(['error' => 'No active subscription']);
        exit();
    }

    $subscriptionId     = (int)$subscription['id'];
    $totalLeadsClaimed  = (int)$subscription['total_leads_claimed'];

    // Fetch total max claims for this level
    $stmt = $pdo->prepare("
        SELECT setting_value
        FROM system_settings
        WHERE setting_key = 'max_total_claims'
          AND user_level = ?
        LIMIT 1
    ");
    $stmt->execute([$userLevel]);
    $maxTotalClaims = (int)$stmt->fetchColumn();

    if ($maxTotalClaims === 0 || $totalLeadsClaimed >= $maxTotalClaims) {
        // Mark subscription inactive
        $pdo->prepare("
            UPDATE subscription_history
            SET status = 'expired'
            WHERE id = ?
        ")->execute([$subscriptionId]);

        // Mark user inactive (trigger handles level change)
        $pdo->prepare("
            UPDATE users
            SET status = 'inactive'
            WHERE id = ?
        ")->execute([$userId]);

        http_response_code(403);
        echo json_encode(['error' => 'Subscription limit reached']);
        exit();
    }

    // Fetch daily claim limit
    $stmt = $pdo->prepare("
        SELECT setting_value
        FROM system_settings
        WHERE setting_key = 'max_claims_per_day'
          AND user_level = ?
        LIMIT 1
    ");
    $stmt->execute([$userLevel]);
    $maxClaimsPerDay = (int)$stmt->fetchColumn();
    if ($maxClaimsPerDay <= 0) $maxClaimsPerDay = 4;

    // Begin transaction
    $pdo->beginTransaction();

    // Lock lead row for atomic claim
    $stmt = $pdo->prepare("
        SELECT id, event_date, is_locked, claimed_by, max_claims_allowed
        FROM leads
        WHERE id = ?
        FOR UPDATE
    ");
    $stmt->execute([$leadId]);
    $lead = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$lead) {
        $pdo->rollBack();
        http_response_code(404);
        echo json_encode(['error' => 'Lead not found']);
        exit();
    }

    // Single active claimer rule: if already locked/claimed by another user, reject.
    if ((int)$lead['is_locked'] === 1 && (int)$lead['claimed_by'] !== $userId) {
        $pdo->rollBack();
        http_response_code(409);
        echo json_encode(['error' => 'Lead already claimed by another user']);
        exit();
    }

    // Event date validation
    if (!empty($lead['event_date']) && strtotime($lead['event_date']) < strtotime('+2 day')) {
        $pdo->rollBack();
        http_response_code(404);
        echo json_encode(['error' => 'Event too close or expired']);
        exit();
    }

    // Daily claim count
    $stmt = $pdo->prepare("
        SELECT COUNT(*)
        FROM claimed_leads_log
        WHERE user_id = ?
          AND DATE(claim_time) = CURDATE()
    ");
    $stmt->execute([$userId]);
    $claimsToday = (int)$stmt->fetchColumn();

    if ($claimsToday >= $maxClaimsPerDay) {
        $pdo->rollBack();
        http_response_code(429);
        echo json_encode(['error' => 'Daily claim limit reached']);
        exit();
    }

    // Check existing active claim by this user
    $stmt = $pdo->prepare("
        SELECT id
        FROM claimed_leads_log
        WHERE lead_id = ?
          AND user_id = ?
          AND release_time IS NULL
        LIMIT 1
    ");
    $stmt->execute([$leadId, $userId]);
    if ($stmt->fetch()) {
        $pdo->rollBack();
        http_response_code(409);
        echo json_encode(['error' => 'Lead already claimed']);
        exit();
    }

    // Active claims on this lead
    $stmt = $pdo->prepare("
        SELECT COUNT(DISTINCT user_id)
        FROM claimed_leads_log
        WHERE lead_id = ?
          AND release_time IS NULL
    ");
    $stmt->execute([$leadId]);
    $activeClaims = (int)$stmt->fetchColumn();

    if ($activeClaims >= (int)$lead['max_claims_allowed']) {
        $pdo->rollBack();
        http_response_code(409);
        echo json_encode(['error' => 'Lead fully claimed']);
        exit();
    }

    // Fetch claim lock duration (in hours)
    $stmt = $pdo->prepare("
        SELECT setting_value
        FROM system_settings
        WHERE setting_key = 'claim_lock_duration_hours'
        AND user_level = 3
        LIMIT 1
    ");
    $stmt->execute();
    $lockDurationHours = (int)$stmt->fetchColumn();

    // fallback (safety)
    if ($lockDurationHours <= 0) {
        $lockDurationHours = 48;
    }

    // Insert claim log
    $stmt = $pdo->prepare("
        INSERT INTO claimed_leads_log (lead_id, user_id, claim_time)
        VALUES (?, ?, NOW())
    ");
    $stmt->execute([$leadId, $userId]);
    $claimId = $pdo->lastInsertId();

    // Lead status history
    $stmt = $pdo->prepare("
        INSERT INTO lead_status_history
        (lead_id, old_status, new_status, changed_by, changed_at)
        VALUES (?, NULL, 'new', ?, NOW())
    ");
    $stmt->execute([$leadId, $userId]);

    // Update lead metadata
    $stmt = $pdo->prepare("
        UPDATE leads
        SET claim_count = COALESCE(claim_count,0) + 1,
            claimed_by = ?,
            claim_time = NOW(),
            claim_expiry = DATE_ADD(NOW(), INTERVAL ? HOUR),
            is_locked = 1
        WHERE id = ?
        AND (is_locked = 0 OR claimed_by = ?)
    ");
    $stmt->execute([$userId, $lockDurationHours, $leadId, $userId]);

    if ($stmt->rowCount() === 0) {
        $pdo->rollBack();
        http_response_code(409);
        echo json_encode(['error' => 'Lead already claimed by another user']);
        exit();
    }

    // Increment subscription usage
    $stmt = $pdo->prepare("
        UPDATE subscription_history
        SET total_leads_claimed = total_leads_claimed + 1
        WHERE id = ?
    ");
    $stmt->execute([$subscriptionId]);

    $pdo->commit();

    echo json_encode([
        'success' => true,
        'message' => 'Lead claimed successfully',
        'lead_id' => $leadId,
        'claim_id' => $claimId
    ]);
    exit();

} catch (Exception $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    http_response_code(500);
    echo json_encode(['error' => 'Server error']);
    exit();
}
