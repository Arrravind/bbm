<?php
header('Content-Type: application/json');
include 'config/database.php';

$payload = json_decode(file_get_contents("php://input"), true);
$merchant_order_id = $payload['merchantOrderId'] ?? null;
$status = $payload['status'] ?? null; // 'SUCCESS' or 'FAILED'

if(!$merchant_order_id || !$status){
    http_response_code(400);
    echo json_encode(['error'=>'Missing parameters']);
    exit();
}

$pdo = new PDO(
    "mysql:host=".DB_HOST.";dbname=".DB_NAME.";charset=utf8mb4",
    DB_USER, DB_PASS,
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$db_status = $status === 'SUCCESS' ? 'success' : 'failed';
$stmt = $pdo->prepare("UPDATE orders SET status=? WHERE merchant_order_id=?");
$stmt->execute([$db_status, $merchant_order_id]);

// Optional: Update user subscription
if($db_status === 'success'){
    $stmt = $pdo->prepare("UPDATE users SET subscription_plan=? WHERE id=?");
    $stmt->execute([$payload['plan'] ?? 'basic', $payload['userId'] ?? 0]);
}

echo json_encode(['success'=>true]);
?>
