<?php
date_default_timezone_set('Asia/Kolkata');
header("Content-Type: application/json");

require __DIR__ . "/../../app/config/database.php";

$pdo = new PDO(
  "mysql:host=".DB_HOST.";dbname=".DB_NAME.";charset=utf8mb4",
  DB_USER, DB_PASS,
  [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$stmt = $pdo->query("
  SELECT id, slug, name, price_integer, currency, description, artist_level
  FROM subscription_plans
  WHERE active = 1
");

echo json_encode([
  "success" => true,
  "plans" => $stmt->fetchAll(PDO::FETCH_ASSOC)
]);