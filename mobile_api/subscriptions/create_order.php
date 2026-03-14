<?php
header("Content-Type: application/json");
date_default_timezone_set("Asia/Kolkata");

require __DIR__ . "/../../app/config/database.php";

/* Razorpay credentials*/
define("RAZORPAY_KEY", "rzp_live_S2XFFjRvkMZHEM");
define("RAZORPAY_SECRET", "CgGKEpIYqs5xmMyUzaM8pKnc");

/* Read input */
$input = json_decode(file_get_contents("php://input"), true);
$planId = $input["plan_id"] ?? null;
$userId = $input["user_id"] ?? null;

if (!$planId || !$userId) {
  echo json_encode(["success" => false, "message" => "Invalid input"]);
  exit();
}

/* DB connection */
$pdo = new PDO(
  "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
  DB_USER,
  DB_PASS,
  [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

/* Fetch plan */
$stmt = $pdo->prepare("
  SELECT name, price_integer, currency
  FROM subscription_plans
  WHERE id=? AND active=1
");
$stmt->execute([$planId]);
$plan = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$plan) {
  echo json_encode(["success" => false, "message" => "Plan not found"]);
  exit();
}

$amountPaise = (int)$plan["price_integer"];

/* Create Razorpay order */
$orderData = [
  "amount" => $amountPaise,
  "currency" => $plan["currency"],
  "receipt" => "rcpt_" . $userId . "_" . time(),
  "payment_capture" => 1
];

$ch = curl_init("https://api.razorpay.com/v1/orders");
curl_setopt_array($ch, [
  CURLOPT_RETURNTRANSFER => true,
  CURLOPT_USERPWD => RAZORPAY_KEY . ":" . RAZORPAY_SECRET,
  CURLOPT_POST => true,
  CURLOPT_POSTFIELDS => json_encode($orderData),
  CURLOPT_HTTPHEADER => ["Content-Type: application/json"]
]);

$response = curl_exec($ch);
curl_close($ch);

$order = json_decode($response, true);

if (!isset($order["id"])) {
  echo json_encode(["success" => false, "message" => "Order creation failed"]);
  exit();
}

/* Store order in DB as PENDING (CRITICAL FOR WEBHOOK) */
$stmt = $pdo->prepare("
  INSERT INTO subscription_transactions
  (user_id, plan_id, amount, currency, razorpay_order_id, status)
  VALUES (?, ?, ?, ?, ?, 'pending')
");

$stmt->execute([
  $userId,
  $planId,
  $amountPaise,
  $plan["currency"],
  $order["id"]
]);

/* Send order details to Flutter */
echo json_encode([
  "success" => true,
  "order_id" => $order["id"],
  "amount" => $amountPaise,
  "currency" => $plan["currency"],
  "name" => $plan["name"]
]);
