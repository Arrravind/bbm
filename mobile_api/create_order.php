<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); echo json_encode(['error'=>'Method not allowed']); exit(); }

$input = file_get_contents('php://input');
$data = json_decode($input, true);
if (!$data) $data = $_POST;

// Extract fields
$user_id = $data['userId'] ?? null;
$plan = $data['planName'] ?? null;
$amount = $data['amount'] ?? null; // in paise, e.g., 499900

if (!$user_id || !$plan || !$amount) {
    http_response_code(400);
    echo json_encode(['error'=>'Missing parameters']);
    exit();
}

// Include DB
$config_file = __DIR__ . '/../app/config/database.php';
if (!file_exists($config_file)) { http_response_code(500); echo json_encode(['error'=>'DB config not found']); exit(); }
include $config_file;

try {
    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    // Create unique merchant_order_id
    $merchant_order_id = 'ORD' . time() . rand(1000,9999);

    // Insert order in DB with status pending
    $stmt = $pdo->prepare("INSERT INTO orders (user_id, plan, amount, merchant_order_id, status) VALUES (?, ?, ?, ?, 'PENDING')");
    $stmt->execute([$user_id, $plan, $amount, $merchant_order_id]);

    // Generate PhonePe sandbox payment URL (for testing)
    $payment_url = "https://sandbox.phonepe.com/web/pages/customer-details?token={$merchant_order_id}";

    echo json_encode([
        'success' => true,
        'merchant_order_id' => $merchant_order_id,
        'payment_url' => $payment_url
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error'=>'Order creation failed: ' . $e->getMessage()]);
}
?>
