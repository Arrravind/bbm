<?php
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error'=>'Method not allowed']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);
$merchantOrderId = $data['merchantOrderId'];

try {
    $config_file = __DIR__ . '/../app/config/database.php';
    include $config_file;
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER, DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $stmt = $pdo->prepare("SELECT status FROM orders WHERE merchant_order_id=:oid");
    $stmt->execute([':oid'=>$merchantOrderId]);
    $status = $stmt->fetchColumn();

    echo json_encode(['status'=>$status]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error'=>$e->getMessage()]);
}
