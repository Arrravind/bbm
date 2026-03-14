import 'package:bbm_app/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'update_req_screen.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    bool canContinue = await _checkAppVersionFromServer();

    if (!canContinue) return;

    await _checkForUpdate(); // optional Play Store update

    await _startSplashFlow();
  }

  Future<bool> _checkAppVersionFromServer() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      final currentVersion = packageInfo.version;

      final response = await http
          .get(
            Uri.parse(
              "${ApiConfig.versionCheckEndpoint}?version=$currentVersion&platform=android",
            ),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return true;

      final data = jsonDecode(response.body);

      if (data['force_update'] == true) {
        if (!mounted) return false;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UpdateRequiredScreen(
              message: data['message'],
              playstoreUrl: data['playstore_url'],
            ),
          ),
        );

        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Version check failed: $e");

      return true; // allow app if API fails
    }
  }

  Future<void> _startSplashFlow() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    try {
      await _checkLoginStatus();
    } catch (e) {
      _navigateToLogin();
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      AppUpdateInfo info = await InAppUpdate.checkForUpdate().timeout(
        const Duration(seconds: 5),
      );

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userAuthToken = prefs.getString('auth_token');

      if (userAuthToken == null || userAuthToken.isEmpty) {
        return;
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.saveFCMTokenEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'api_token': userAuthToken, 'fcm_token': token}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint("FCM upload failed");
      }
    } catch (e) {
      debugPrint("FCM upload error: $e");
    }
  }

  Future<String?> _fetchUserStatus(String token) async {
    try {
      final response = await http
          .get(Uri.parse("${ApiConfig.getArtistProfileEndpoint}?token=$token"))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['profile'] != null) {
          return data['profile']['status'];
        }
      }
    } catch (e) {
      debugPrint("Status fetch error: $e");
    }
    return null;
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();

    final String? token = prefs.getString("auth_token");
    final int? level = prefs.getInt("level");
    final String? fcmToken = prefs.getString("fcm_token");

    if (token != null &&
        token.isNotEmpty &&
        fcmToken != null &&
        fcmToken.isNotEmpty) {
      await _sendTokenToServer(fcmToken);
    }

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      _navigateToLogin();
      return;
    }

    final String? userStatus = await _fetchUserStatus(token);

    if (!mounted) return;

    if (userStatus == 'inactive') {
      _navigateToSubscription();
      return;
    }

    if (level == 5) {
      _navigateToSubscription();
      return;
    }

    _navigateToDashboard();
  }

  void _navigateToLogin() {
    if (_navigated || !mounted) return;
    _navigated = true;

    Navigator.pushReplacementNamed(context, "/login");
  }

  void _navigateToSubscription() {
    if (_navigated || !mounted) return;
    _navigated = true;

    Navigator.pushReplacementNamed(context, "/Subscription");
  }

  void _navigateToDashboard() {
    if (_navigated || !mounted) return;
    _navigated = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Icon(Icons.business, size: 50, color: Color(0xFF6A11CB)),
              ),
              SizedBox(height: 20),
              Text(
                "BBM Artist App",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Lead Management System",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
