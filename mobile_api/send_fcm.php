<?php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$rawInput = file_get_contents("php://input");
$input = [];
parse_str($rawInput, $input);

$title = trim($input['title'] ?? '📢 New Lead Available!');
$body  = trim($input['body']  ?? 'A new lead has been added.');
$servicesJson = $input['services'] ?? null;

$services = [];
if ($servicesJson) {
    $decoded = json_decode($servicesJson, true);
    if (is_array($decoded)) {
        $services = array_map('strtolower', $decoded);
    }
}

try {
    $configFile = __DIR__ . '/../app/config/database.php';
    if (!file_exists($configFile)) {
        throw new Exception('Database configuration file missing');
    }

    include $configFile;

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    exit;
}

$stmt = $pdo->prepare("
    SELECT u.id, u.username, u.fcm_token, ap.category
    FROM users u
    LEFT JOIN artist_profiles ap ON ap.user_id = u.id
    WHERE u.fcm_token IS NOT NULL AND u.fcm_token != ''
");
$stmt->execute();
$users = $stmt->fetchAll(PDO::FETCH_ASSOC);

if (!$users) {
    echo json_encode(['success' => false, 'message' => 'No users with valid FCM tokens']);
    exit;
}

$targetUsers = [];

if (!empty($services)) {
    foreach ($users as $user) {
        if (!empty($user['category']) && in_array(strtolower($user['category']), $services)) {
            $targetUsers[] = $user;
        }
    }
} else {
    $targetUsers = $users;
}

if (!$targetUsers) {
    echo json_encode([
        'success' => false,
        'message' => 'No users matched service criteria'
    ]);
    exit;
}

$serviceAccountPath = __DIR__ . '/firebase-service-account.json';
if (!file_exists($serviceAccountPath)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Firebase service account file missing']);
    exit;
}

$accessToken = getFirebaseAccessToken($serviceAccountPath);
$projectId = 'lead-management-app-74c44';

$results = [];

foreach ($targetUsers as $user) {

    $payload = [
        "message" => [
            "token" => $user['fcm_token'],
            "notification" => [
                "title" => $title,
                "body"  => $body
            ],
            "android" => [
                "priority" => "high",
                "notification" => [
                    "channel_id" => "default_channel",
                    "sound" => "default"
                ]
            ],
            "data" => [
                "type" => "new_lead",
                "click_action" => "FLUTTER_NOTIFICATION_CLICK",
                "timestamp" => (string)time()
            ]
        ]
    ];

    $ch = curl_init("https://fcm.googleapis.com/v1/projects/$projectId/messages:send");
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => [
            'Authorization: Bearer ' . $accessToken,
            'Content-Type: application/json'
        ],
        CURLOPT_POSTFIELDS => json_encode($payload)
    ]);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $results[] = [
        'user_id' => $user['id'],
        'username' => $user['username'],
        'http_code' => $httpCode,
        'response' => json_decode($response, true)
    ];
}

echo json_encode([
    'success' => true,
    'sent_to' => count($targetUsers),
    'results' => $results
]);

function getFirebaseAccessToken(string $serviceAccountPath): string
{
    $serviceAccount = json_decode(file_get_contents($serviceAccountPath), true);

    $now = time();
    $jwtHeader = ['alg' => 'RS256', 'typ' => 'JWT'];
    $jwtClaim = [
        'iss' => $serviceAccount['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600
    ];

    $jwt = base64UrlEncode(json_encode($jwtHeader)) . '.' . base64UrlEncode(json_encode($jwtClaim));
    openssl_sign($jwt, $signature, $serviceAccount['private_key'], 'SHA256');
    $jwt .= '.' . base64UrlEncode($signature);

    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt
        ])
    ]);

    $response = curl_exec($ch);
    curl_close($ch);

    $data = json_decode($response, true);

    if (empty($data['access_token'])) {
        throw new Exception('Failed to generate Firebase access token');
    }

    return $data['access_token'];
}

function base64UrlEncode(string $data): string
{
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}
