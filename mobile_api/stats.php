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
    // Load DB config
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

    // Fetch max_claims_per_day from system_settings (for future stats logic)
    $stmt = $pdo->prepare("SELECT setting_value FROM system_settings WHERE setting_key = 'max_claims_per_day' LIMIT 1");
    $stmt->execute();
    $maxClaimsPerDay = (int)($stmt->fetchColumn() ?: 4);

    // Validate token
    $stmt = $pdo->prepare("
        SELECT id, level, status
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
    $userId = (int)$user['id'];
    $userLevel = (int)$user['level'];

    // Optional active subscription stats.
    // Keep claimed lead history available even when there is no active plan.
    $stmt = $pdo->prepare("
        SELECT id, plan_id, plan_name, start_date, total_leads_claimed
        FROM subscription_history
        WHERE user_id = ?
          AND status = 'active'
        ORDER BY start_date DESC
        LIMIT 1
    ");
    $stmt->execute([$userId]);
    $subscription = $stmt->fetch(PDO::FETCH_ASSOC);

    $totalAllowedClaims = 0;
    $claimed = 0;
    $balance = 0;
    $bookedClaims = 0;

    if ($subscription) {
        $stmt = $pdo->prepare("
            SELECT setting_value
            FROM system_settings
            WHERE setting_key = 'max_total_claims'
              AND user_level = ?
            LIMIT 1
        ");
        $stmt->execute([$userLevel]);
        $totalAllowedClaims = (int)($stmt->fetchColumn() ?: 0);

        $claimed = (int)$subscription['total_leads_claimed'];
        $balance = max(0, $totalAllowedClaims - $claimed);

    }

    // Count only bookings explicitly changed by the current user.
    // If an active subscription exists, scope it to that plan window.
    if ($subscription && !empty($subscription['start_date'])) {
        $stmt = $pdo->prepare("
            SELECT COUNT(DISTINCT lead_id)
            FROM lead_status_history
            WHERE changed_by = ?
              AND new_status = 'booked'
              AND changed_at >= ?
        ");
        $stmt->execute([$userId, $subscription['start_date']]);
    } else {
        $stmt = $pdo->prepare("
            SELECT COUNT(DISTINCT lead_id)
            FROM lead_status_history
            WHERE changed_by = ?
              AND new_status = 'booked'
        ");
        $stmt->execute([$userId]);
    }
    $bookedClaims = (int)$stmt->fetchColumn();

    // Fetch latest status per lead for this user
    $stmt = $pdo->prepare("
        SELECT lsh.lead_id,
               lsh.new_status,
               lsh.changed_at,
               l.customer_name,
               l.event_date,
               l.claim_expiry,
               l.is_locked,
               l.claimed_by
        FROM lead_status_history lsh
        INNER JOIN (
            SELECT lead_id, MAX(changed_at) as latest_change
            FROM lead_status_history
            WHERE changed_by = ?
            GROUP BY lead_id
        ) latest
          ON latest.lead_id = lsh.lead_id AND latest.latest_change = lsh.changed_at
        INNER JOIN leads l ON l.id = lsh.lead_id
        ORDER BY latest.latest_change DESC
    ");
    $stmt->execute([$userId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Format claimed leads
    $formattedAllLeads = [];
    foreach ($rows as $lead) {
        // Determine released status
        $isReleased = 0; // default: not released

        if ((int)$lead['claimed_by'] !== $userId) {
            $isReleased = 1;
        } elseif ((int)$lead['is_locked'] === 0) {
            $isReleased = 1;
        } elseif ($lead['claim_expiry'] !== null && strtotime($lead['claim_expiry']) < time()) {
            $isReleased = 1;
        }

        $formattedAllLeads[] = [
            'id'            => (int)$lead['lead_id'],
            'customer_name' => $lead['customer_name'] ?: 'Unknown',
            'name'          => $lead['customer_name'] ?: 'Unknown',
            'event_date'    => $lead['event_date'] ?: '',
            'date'          => $lead['event_date'] ? date('Y-m-d', strtotime($lead['event_date'])) : '',
            'status'        => $lead['new_status'] ?: 'new',
            'last_updated'  => $lead['changed_at'],
            'released'      => $isReleased
        ];
    }

    // Count stats (use formattedAllLeads to stay consistent with my_claims)
    $total_claims     = count($formattedAllLeads);
    $new_claims       = 0;
    $contacted_claims = 0;
    $booked_claims    = 0;

    foreach ($formattedAllLeads as $lead) {
        switch (strtolower($lead['status'])) {
            case 'new':
                $new_claims++;
                break;
            case 'contacted':
                $contacted_claims++;
                break;
            case 'booked':
                $booked_claims++;
                break;
        }
    }

    // Recent = last 10 claimed/updated leads
    $recentLeads = array_slice($formattedAllLeads, 0, 10);

    echo json_encode([
        'success'          => true,
        'total_allowed'    => $totalAllowedClaims,
        'claimed'          => $claimed,
        'balance'          => $balance,
        'booked_claims'    => $bookedClaims,
        'total_claims'     => $total_claims,
        'new_claims'       => $new_claims,
        'contacted_claims' => $contacted_claims,
        'recent_leads'     => $recentLeads,
        'claimed_leads'    => $formattedAllLeads
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to fetch stats: ' . $e->getMessage()]);
}
