import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'available_leads_page.dart';
import 'dashboard_page.dart';
import 'register_page.dart';
import 'settings_page.dart';
import 'my_claims_page.dart';
import 'splash_page.dart';
import 'lead_detail_page.dart';
import 'subscription.dart';
import 'leads_home_page.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Background notification handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("📩 Background message: ${message.notification?.title}");
}

// Flutter Local Notifications setup
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> checkInitialMessage() async {
  RemoteMessage? initialMessage = await FirebaseMessaging.instance
      .getInitialMessage();

  if (initialMessage != null) {
    debugPrint(
      '🚀 App launched via terminated notification: ${initialMessage.data}',
    );
    // Handle deep linking or navigation here
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Setup local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
    'default_channel',
    'General Notifications',
    description: 'Channel for general notifications',
    importance: Importance.high,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(defaultChannel);

  // Initialize FCM and permissions
  await _initializeFCM();

  await checkInitialMessage();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

Future<void> _initializeFCM() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request notification permission
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ Notification permission not granted.');
      return;
    }

    // 🔴 IMPORTANT: delay token fetch (prevents SERVICE_NOT_AVAILABLE)
    await Future.delayed(const Duration(seconds: 5));

    try {
      String? token = await messaging.getToken();
      debugPrint('✅ FCM Token: $token');

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
      }
    } catch (e) {
      debugPrint('⚠️ FCM token fetch failed: $e');
    }

    // 🔄 Token refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', newToken);
      } catch (e) {
        debugPrint('⚠️ Token refresh save failed: $e');
      }
    });

    // 💬 Foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      try {
        debugPrint("💬 Foreground message: ${message.notification?.title}");
        _showLocalNotification(message);
      } catch (e) {
        debugPrint('⚠️ Foreground handler error: $e');
      }
    });

    // 🚀 App opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      try {
        debugPrint("🚀 App opened via notification: ${message.data}");
        // Optional: navigation / deep link
      } catch (e) {
        debugPrint('⚠️ onMessageOpenedApp error: $e');
      }
    });
  } catch (e) {
    debugPrint('🔥 FCM initialization failed: $e');
  }
}

void _showLocalNotification(RemoteMessage message) {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  if (notification != null && android != null) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title ?? 'No Title',
      notification.body ?? 'No Body',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel', // channel id
          'General Notifications', // channel name
          channelDescription: 'Shows app notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Artist Dashboard',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      routes: {
        '/': (context) => const SplashPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/settings': (context) => const SettingsPage(),
        '/leads': (context) => const LeadsHomePage(),
        '/available_leads': (context) => const AvailableLeadsPage(),
        '/my_claims': (context) => const MyClaimsPage(),
        '/lead_detail': (context) => const LeadDetailPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/Subscription': (context) => const Level5SubscriptionPage(),
      },
    );
  }
}
