<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit();
}

$input = file_get_contents('php://input');
$data = json_decode($input, true);
if (!$data) $data = $_POST;

// Extract fields
$whatsapp   = trim($data['whatsapp'] ?? '');
$password   = trim($data['password'] ?? '');
$business   = trim($data['business_name'] ?? '');
$contact    = trim($data['contact_person'] ?? '');
$instagram  = trim($data['instagram'] ?? '');
$category   = trim($data['category'] ?? '');
$coupon     = trim($data['coupon_code'] ?? '');

$errors = [];

// Validate WhatsApp (username)
if (!preg_match('/^[0-9]{10}$/', $whatsapp)) {
    $errors['whatsapp'] = "WhatsApp number must be exactly 10 digits.";
}

// Validate password
if (strlen($password) < 8 || strlen($password) > 50) {
    $errors['password'] = "Password must be 8–50 characters.";
} elseif (!preg_match('/[0-9]/', $password)) {
    $errors['password'] = "Password must contain at least one number.";
} elseif (!preg_match('/[\W_]/', $password)) {
    $errors['password'] = "Password must contain at least one special character.";
}

// Validate other required fields
if (empty($business))  $errors['business_name'] = "Business name is required.";
if (empty($contact))   $errors['contact_person'] = "Contact person name is required.";
if (empty($instagram)) $errors['instagram'] = "Instagram handle is required.";

function send_email_notification($userData) {
    try {
        $to = 'rep123hel@gmail.com'; // Admin email
        $subject = 'New Artist Registration - BridalBooker Machine';

        $whatsapp   = $userData['whatsapp'] ?? 'N/A';
        $business   = $userData['business_name'] ?? 'N/A';
        $contact    = $userData['contact_person'] ?? 'N/A';
        $instagram  = $userData['instagram'] ?? 'N/A';
        $category   = $userData['category'] ?? 'N/A';
        $coupon     = $userData['coupon_code'] ?? 'Not Applied';

        $message = "
        <html>
        <head>
            <title>New Artist Registration</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                }
                .container {
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 20px;
                }
                .header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 20px;
                    text-align: center;
                    border-radius: 10px 10px 0 0;
                }
                .content {
                    background: #f9f9f9;
                    padding: 20px;
                    border-radius: 0 0 10px 10px;
                }
                .field {
                    margin-bottom: 12px;
                }
                .label {
                    font-weight: bold;
                    color: #555;
                }
                .value {
                    background: #ffffff;
                    padding: 8px;
                    border-radius: 5px;
                    margin-top: 4px;
                }
            </style>
        </head>
        <body>
            <div class='container'>
                <div class='header'>
                    <h2>🎉 New Artist Registered</h2>
                    <p>BridalBooker Machine</p>
                </div>
                <div class='content'>
                    <div class='field'>
                        <div class='label'>Business Name</div>
                        <div class='value'>{$business}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Contact Person</div>
                        <div class='value'>{$contact}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>WhatsApp Number</div>
                        <div class='value'>+91 {$whatsapp}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Instagram Handle</div>
                        <div class='value'>{$instagram}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Category</div>
                        <div class='value'>{$category}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Coupon Code</div>
                        <div class='value'>{$coupon}</div>
                    </div>
                    <div class='field'>
                        <div class='label'>Account Status</div>
                        <div class='value'>Inactive (Level 5)</div>
                    </div>
                </div>
            </div>
        </body>
        </html>
        ";

        $headers  = "MIME-Version: 1.0\r\n";
        $headers .= "Content-type:text/html;charset=UTF-8\r\n";
        $headers .= "From: BridalBooker Machine <noreply@bridalbookermachine.com>\r\n";
        $headers .= "Reply-To: noreply@bridalbookermachine.com\r\n";

        $mail_sent = mail($to, $subject, $message, $headers);

        if ($mail_sent) {
            error_log("Artist registration email sent successfully for WhatsApp: " . $whatsapp);
        } else {
            error_log("Failed to send artist registration email for WhatsApp: " . $whatsapp);
        }
    } catch (Exception $e) {
        error_log("Email Error: " . $e->getMessage());
    }
}

try {
    $config_file = __DIR__ . '/../app/config/database.php';
    if (!file_exists($config_file)) throw new Exception('Database config not found');
    include $config_file;

    $pdo = new PDO(
        "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4",
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );

    $pdo->exec("SET time_zone = '+05:30'");

    // Ensure artist_profiles has `category` and `coupon_code` columns (add if missing)
    $colsToEnsure = [
        'category' => "VARCHAR(255) NOT NULL DEFAULT ''",
        'coupon_code' => "VARCHAR(100) DEFAULT NULL"
    ];
    foreach ($colsToEnsure as $col => $def) {
        $colStmt = $pdo->prepare("SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?");
        $colStmt->execute([DB_NAME, 'artist_profiles', $col]);
        if ($colStmt->fetchColumn() == 0) {
            $pdo->exec("ALTER TABLE artist_profiles ADD COLUMN `$col` $def");
        }
    }

    // Check duplicates
    if (empty($errors)) {
        $stmt = $pdo->prepare("SELECT COUNT(*) FROM users WHERE username = ?");
        $stmt->execute([$whatsapp]);
        if ($stmt->fetchColumn() > 0) $errors['whatsapp'] = "This WhatsApp number is already registered.";
    }

    if (!empty($errors)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'errors' => $errors]);
        exit();
    }

    $password_hash = password_hash($password, PASSWORD_DEFAULT);

    $pdo->beginTransaction();

    // $email = $data['email'] ?? 'dummy_' . uniqid() . '@example.com';

    $stmt = $pdo->prepare("
        INSERT INTO users (username, password_hash, role, status, created_at, level)
        VALUES (?, ?, 'artist', 'inactive', NOW(), 5)
    ");
    $stmt->execute([$whatsapp, $password_hash]);
    
    $user_id = $pdo->lastInsertId();

    // Generate token
    $token = base64_encode($user_id . ':' . time() . ':' . md5($whatsapp));
    $stmt = $pdo->prepare("
        UPDATE users 
        SET api_token = ?, token_expires = DATE_ADD(NOW(), INTERVAL 30 DAY) 
        WHERE id = ?
    ");
    $stmt->execute([$token, $user_id]);

    // Insert into artist_profiles with level = 5 (store category & coupon_code)
    $stmt = $pdo->prepare("
        INSERT INTO artist_profiles (user_id, contact_person_name, business_name, instagram_handle, whatsapp_number, category, coupon_code, is_active, artist_level, created_at, updated_at) 
        VALUES (?, ?, ?, ?, ?, ?, ?, 0, '5', NOW(), NOW())
    ");
    $couponParam = $coupon !== '' ? $coupon : null;
    $stmt->execute([$user_id, $contact, $business, $instagram, $whatsapp, $category, $couponParam]);

    $pdo->commit();

    echo json_encode([
        'success' => true,
        'message' => 'Registration successful',
        'token' => $token,
        'user' => [
            'id' => (int)$user_id,
            'username' => $whatsapp,
            'role' => 'artist',
            'business_name' => $business,
            'level' => (int)5       
        ]
    ]);

    // Send email notification to admin
    send_email_notification($data);

} catch (Exception $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    http_response_code(500);
    echo json_encode(['error' => 'Registration failed: ' . $e->getMessage()]);
}
?>
