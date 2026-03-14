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
// import 'lead_detail_page.dart';
import 'new_lead_details.dart';
import 'subscription.dart';
import 'leads_home_page.dart';
import 'assign_artist_page.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Background notification handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Background message: ${message.notification?.title}");
}

// Local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint("Firebase init failed or timed out: $e");
  }

  // Register background handler AFTER Firebase init
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // System UI (safe)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // UI FIRST — this prevents white screen
  runApp(const MyApp());

  // EVERYTHING BELOW RUNS AFTER UI LOADS
  _postAppStartupInit();
}

// Runs after UI is visible (cannot block splash)
Future<void> _postAppStartupInit() async {
  await _initializeLocalNotifications();
  await _initializeFCM();
  await _checkInitialMessage();
}

// Local notifications setup (unchanged, guarded)
Future<void> _initializeLocalNotifications() async {
  try {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationChannel defaultChannel =
        AndroidNotificationChannel(
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
  } catch (e) {
    debugPrint("Local notification init failed: $e");
  }
}

// Handle terminated notification
Future<void> _checkInitialMessage() async {
  try {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();

    if (initialMessage != null) {
      debugPrint(
        '🚀 App launched via terminated notification: ${initialMessage.data}',
      );
      // Optional deep-link handling
    }
  } catch (e) {
    debugPrint("⚠️ Initial message check failed: $e");
  }
}

// Firebase Cloud Messaging initialization
Future<void> _initializeFCM() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings;

    try {
      settings = await messaging
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Notification permission timeout: $e");
      return;
    }

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('Notification permission not granted.');
      return;
    }

    // Delay token fetch (your original logic preserved)
    await Future.delayed(const Duration(seconds: 5));

    try {
      String? token = await messaging.getToken();
      debugPrint('FCM Token: $token');

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
      }
    } catch (e) {
      debugPrint('FCM token fetch failed: $e');
    }

    // Token refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        debugPrint('FCM Token refreshed: $newToken');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', newToken);
      } catch (e) {
        debugPrint('Token refresh save failed: $e');
      }
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      try {
        debugPrint("Foreground message: ${message.notification?.title}");
        _showLocalNotification(message);
      } catch (e) {
        debugPrint('Foreground handler error: $e');
      }
    });

    // App opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      try {
        debugPrint("App opened via notification: ${message.data}");
      } catch (e) {
        debugPrint('onMessageOpenedApp error: $e');
      }
    });
  } catch (e) {
    debugPrint('FCM initialization failed: $e');
  }
}

// Show local notification (unchanged)
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
          'default_channel',
          'General Notifications',
          channelDescription: 'Shows app notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
    );
  }
}

// App widget (UNCHANGED)
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
        '/assign_artist': (context) => const AssignArtistPage(),
      },
    );
  }
}
