<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$version = $_GET['version'] ?? '';
$platform = $_GET['platform'] ?? 'android';

if (empty($version)) {
    http_response_code(400);
    echo json_encode(['error' => 'Version required']);
    exit();
}

try {

    include __DIR__ . '/../app/config/database.php';

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $stmt = $pdo->prepare("
        SELECT latest_version, minimum_version, update_required,
               update_message, playstore_url
        FROM app_version_config
        WHERE platform = ?
        AND status = 1
        ORDER BY id DESC
        LIMIT 1
    ");

    $stmt->execute([$platform]);

    $config = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$config) {
        throw new Exception("Version config not found");
    }

    $forceUpdate = version_compare($version, $config['minimum_version'], '<');

    echo json_encode([
        "success" => true,
        "latest_version" => $config['latest_version'],
        "minimum_version" => $config['minimum_version'],
        "force_update" => $forceUpdate,
        "update_required" => (bool)$config['update_required'],
        "message" => $config['update_message'],
        "playstore_url" => $config['playstore_url']
    ]);

} catch (Exception $e) {

    http_response_code(500);

    echo json_encode([
        "error" => $e->getMessage()
    ]);
}
