<?php

header("Content-Type: application/json");
require __DIR__ . "/../../app/config/database.php";

define("RAZORPAY_SECRET", "CgGKEpIYqs5xmMyUzaM8pKnc");

// Toggle debug mode
$DEBUG_MODE = true;
$debug = [];

function log_debug(&$debug, $msg) {
    global $DEBUG_MODE;
    if ($DEBUG_MODE) {
        $debug[] = $msg;
        error_log("[PAYMENT] " . $msg);
    }
}

try {

    $input = json_decode(file_get_contents("php://input"), true);
    log_debug($debug, "Incoming: " . json_encode($input));

    $userId    = $input["user_id"] ?? null;
    $planId    = $input["plan_id"] ?? null;
    $paymentId = $input["razorpay_payment_id"] ?? null;
    $orderId   = $input["razorpay_order_id"] ?? null;
    $signature = $input["razorpay_signature"] ?? null;

    // Validation
    if (!$paymentId || !$orderId || !$signature || !$userId || !$planId) {
        echo json_encode([
            "success" => false,
            "error_code" => "MISSING_FIELDS",
            "message" => "Required fields missing",
            "debug" => $debug
        ]);
        exit();
    }

    // Signature Verification
    $generated = hash_hmac(
        "sha256",
        $orderId . "|" . $paymentId,
        RAZORPAY_SECRET
    );

    log_debug($debug, "Generated signature: $generated");
    log_debug($debug, "Received signature: $signature");

    if (!hash_equals($generated, $signature)) {
        echo json_encode([
            "success" => false,
            "error_code" => "INVALID_SIGNATURE",
            "message" => "Payment verification failed",
            "debug" => $debug
        ]);
        exit();
    }

    log_debug($debug, "Signature verified");

    // DB Connection
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $pdo->beginTransaction();

    // Update transaction
    $stmt = $pdo->prepare("
        UPDATE subscription_transactions
        SET razorpay_payment_id = ?, status = 'success'
        WHERE razorpay_order_id = ? AND status = 'pending'
    ");
    $stmt->execute([$paymentId, $orderId]);

    log_debug($debug, "Transaction rows updated: " . $stmt->rowCount());

    if ($stmt->rowCount() === 0) {
        throw new Exception("ORDER_ALREADY_PROCESSED");
    }

    // Fetch plan
    $stmt = $pdo->prepare("
        SELECT id, slug, duration_days, artist_level
        FROM subscription_plans
        WHERE id = ?
        LIMIT 1
    ");
    $stmt->execute([$planId]);
    $plan = $stmt->fetch(PDO::FETCH_ASSOC);

    log_debug($debug, "Plan data: " . json_encode($plan));

    if (!$plan) {
        throw new Exception("INVALID_PLAN");
    }

    $durationDays = (int)$plan['duration_days'];

    // Expire old
    $pdo->prepare("
        UPDATE subscription_history
        SET status = 'expired'
        WHERE user_id = ? AND status = 'active'
    ")->execute([$userId]);

    log_debug($debug, "Old subscriptions expired");

    // Insert new subscription
    $stmt = $pdo->prepare("
        INSERT INTO subscription_history
        (
            user_id, plan_id, plan_name, subscription_type,
            start_date, end_date, total_leads_claimed,
            amount_paid, payment_id, order_id, status
        )
        SELECT
            :user_id, :plan_id, sp.name, 'paid',
            NOW(),
            DATE_ADD(NOW(), INTERVAL :duration DAY),
            0,
            st.amount,
            :payment_id,
            :order_id,
            'active'
        FROM subscription_transactions st
        JOIN subscription_plans sp ON sp.id = st.plan_id
        WHERE st.razorpay_order_id = :order_id
        LIMIT 1
    ");

    $stmt->execute([
        ':duration' => $durationDays,
        ':user_id' => $userId,
        ':plan_id' => $planId,
        ':payment_id' => $paymentId,
        ':order_id' => $orderId
    ]);

    log_debug($debug, "Subscription inserted");

    // Artist level mapping
    $artistLevel = (int)$plan['artist_level'];

    log_debug($debug, "Artist level: " . $artistLevel);

    if ($artistLevel === null) {
        throw new Exception("INVALID_PLAN_MAPPING");
    }

    // Update artist profile
    $pdo->prepare("
        UPDATE artist_profiles
        SET artist_level = ?, is_active = 1
        WHERE user_id = ?
    ")->execute([$artistLevel, $userId]);

    // Update user
    $pdo->prepare("
        UPDATE users
        SET status = 'active', level = ?
        WHERE id = ?
    ")->execute([$artistLevel, $userId]);

    $pdo->commit();

    echo json_encode([
        "success" => true,
        "message" => "Payment successful",
        "debug" => $debug
    ]);

} catch (Exception $e) {

    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    $errorCode = $e->getMessage();

    log_debug($debug, "Exception: " . $errorCode);

    echo json_encode([
        "success" => false,
        "error_code" => $errorCode,
        "message" => match ($errorCode) {
            "ORDER_ALREADY_PROCESSED" => "Order already processed",
            "INVALID_PLAN" => "Invalid subscription plan",
            "INVALID_PLAN_MAPPING" => "Plan mapping error",
            default => "Server error occurred"
        },
        "debug" => $debug
    ]);
}