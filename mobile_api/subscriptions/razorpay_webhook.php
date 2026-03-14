<?php
header("Content-Type: application/json");

require __DIR__ . "/../../app/config/database.php";

define("WEBHOOK_SECRET", "CgGKEpIYqs5xmMyUzaM8pKnc");

$payload = file_get_contents("php://input");
$signature = $_SERVER["HTTP_X_RAZORPAY_SIGNATURE"] ?? "";

$expected = hash_hmac("sha256", $payload, WEBHOOK_SECRET);

if (!hash_equals($expected, $signature)) {
  http_response_code(400);
  exit("Invalid signature");
}

$data = json_decode($payload, true);

if ($data["event"] !== "payment.captured") {
  exit("Ignored");
}

$paymentId = $data["payload"]["payment"]["entity"]["id"];
$orderId   = $data["payload"]["payment"]["entity"]["order_id"];
$amount    = $data["payload"]["payment"]["entity"]["amount"];

$pdo = new PDO(
  "mysql:host=".DB_HOST.";dbname=".DB_NAME.";charset=utf8mb4",
  DB_USER, DB_PASS,
  [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$stmt = $pdo->prepare("
  UPDATE subscription_transactions
  SET status='success'
  WHERE razorpay_order_id=?
");
$stmt->execute([$orderId]);

echo json_encode(["success" => true]);
