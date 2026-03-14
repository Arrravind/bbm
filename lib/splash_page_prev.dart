import 'package:bbm_app/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'package:in_app_update/in_app_update.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    checkForUpdate();
    _checkLoginStatus();
  }

  Future<void> checkForUpdate() async {
    try {
      AppUpdateInfo info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          // FORCE UPDATE
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          // OPTIONAL UPDATE
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint("UPDATE ERROR: $e");
    }
  }

  // Sends the FCM token to your backend server using stored API token
  Future<void> _sendTokenToServer(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userAuthToken = prefs.getString('auth_token');

      if (userAuthToken == null || userAuthToken.isEmpty) {
        debugPrint('⚠️ No user auth token found. Skipping FCM upload.');
        return;
      }

      const String apiUrl = ApiConfig.saveFCMTokenEndpoint;

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_token': userAuthToken, 'fcm_token': token}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ FCM token sent successfully to backend');
        } else {
          debugPrint('⚠️ Failed to update token: ${data['message']}');
        }
      } else {
        debugPrint('❌ Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('💥 Error sending token: $e');
    }
  }

  Future<String?> _fetchUserStatus(String token) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.getArtistProfileEndpoint}?token=$token"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['profile'] != null) {
          return data['profile']['status'] ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error fetching user status: $e');
    }
    return null;
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("auth_token");
    int? level = prefs.getInt("level");
    String? fcmToken = prefs.getString("fcm_token");

    if (token != null &&
        token.isNotEmpty &&
        fcmToken != null &&
        fcmToken.isNotEmpty) {
      debugPrint('📤 Sending stored FCM token on app start...');
      await _sendTokenToServer(fcmToken);
    }

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      String? userStatus = await _fetchUserStatus(token);

      if (!mounted) return;

      if (userStatus == 'inactive') {
        Navigator.pushReplacementNamed(context, "/Subscription");
      } else {
        if (level == 5) {
          Navigator.pushReplacementNamed(context, "/Subscription");
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainShell()),
          );
        }
      }
    } else {
      Navigator.pushReplacementNamed(context, "/login");
    }
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
