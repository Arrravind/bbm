<?php
require __DIR__ . '/vendor/autoload.php';

use Google\Client;
use GuzzleHttp\Client as GuzzleClient;

// ---- CONFIGURATION ----

// Path to your service account key file (uploaded securely to the same folder)
$serviceAccountPath = __DIR__ . '/firebase-service-account.json';

// The FCM device token you want to test
// (use the one stored in your database for your device)
$fcmToken = 'cSps9mApRGSo-TJf_OwfPm:APA91bFf-X4-UbRYFXcaSCc8pVXup6DgYmDf_bDmyqXGySl6iEuvXNIpLSvPQ52ETULoSmTM5rrDmBMS573tHQjsTmRVi9hiXxB1QTHxaHdUFQ3QVQTvbUo';

// ---- STEP 1: Get Access Token ----
$client = new Client();
$client->setAuthConfig($serviceAccountPath);
$client->addScope('https://www.googleapis.com/auth/firebase.messaging');

$accessToken = $client->fetchAccessTokenWithAssertion()['access_token'];

// ---- STEP 2: Prepare Notification Payload ----
$projectId = 'lead-management-app-74c44'; // Replace with your Firebase project ID
$url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";

$payload = [
    "message" => [
        "token" => $fcmToken,
        "notification" => [
            "title" => "🔥 Test Notification",
            "body"  => "This is a test push notification from your server."
        ],
        "data" => [
            "type" => "test",
            "click_action" => "FLUTTER_NOTIFICATION_CLICK"
        ]
    ]
];

// ---- STEP 3: Send Notification ----
$httpClient = new GuzzleClient();

$response = $httpClient->post($url, [
    'headers' => [
        'Authorization' => "Bearer $accessToken",
        'Content-Type' => 'application/json',
    ],
    'json' => $payload,
]);

// ---- STEP 4: Print Result ----
echo "✅ Notification sent successfully:<br>";
print_r(json_decode($response->getBody()->getContents(), true));
