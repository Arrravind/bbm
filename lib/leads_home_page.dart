import 'dart:convert';

import 'package:bbm_app/config/api_config.dart';
import 'package:bbm_app/widgets/app_error_view.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'available_leads_page.dart';
import 'my_claims_page.dart';

class LeadsHomePage extends StatefulWidget {
  final int initialTabIndex;

  const LeadsHomePage({super.key, this.initialTabIndex = 0});

  @override
  State<LeadsHomePage> createState() => _LeadsHomePageState();
}

enum LeadsHomeErrorType { none, network, sessionExpired }

class _LeadsHomePageState extends State<LeadsHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  LeadsHomeErrorType errorType = LeadsHomeErrorType.none;
  String? errorMessage;
  bool isLoading = true;

  int availableCount = 0;
  int myClaimsCount = 0;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    _fetchCounts();

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _maybeShowDisclaimer();
    // });
  }

  Future<void> _fetchCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    if (token == null) {
      setState(() {
        errorType = LeadsHomeErrorType.sessionExpired;
        errorMessage = "Your session has expired. Please login again.";
        isLoading = false;
      });
      return;
    }

    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.claimStatsEndpoint}?token=$token"),
      );

      Map<String, dynamic>? statsData;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          statsData = decoded;
        }
      } catch (_) {}

      final statsError =
          (statsData?["error"] ?? statsData?["message"] ?? "").toString().toLowerCase();
      final statsTokenError =
          res.statusCode == 401 || statsError.contains("token") || statsError.contains("session");

      if (statsTokenError) {
        setState(() {
          errorType = LeadsHomeErrorType.sessionExpired;
          errorMessage = "Your account was logged in on another device.";
          isLoading = false;
        });
        return;
      }

      if (res.statusCode != 200) {
        setState(() {
          errorType = LeadsHomeErrorType.network;
          errorMessage =
              (statsData?["error"] ?? statsData?["message"] ?? "Unable to connect. Please check your internet.")
                  .toString();
          isLoading = false;
        });
        return;
      }

      myClaimsCount = statsData?["total_claims"] ?? 0;

      final leadsRes = await http.get(
        Uri.parse("${ApiConfig.availableLeadsEndpoint}?token=$token"),
      );

      Map<String, dynamic>? leadsData;
      try {
        final decoded = jsonDecode(leadsRes.body);
        if (decoded is Map<String, dynamic>) {
          leadsData = decoded;
        }
      } catch (_) {}

      final leadsError =
          (leadsData?["error"] ?? leadsData?["message"] ?? "").toString().toLowerCase();
      final leadsTokenError = leadsRes.statusCode == 401 ||
          leadsError.contains("token") ||
          leadsError.contains("session");
      final leadsSubscriptionError = leadsRes.statusCode == 403 ||
          leadsError.contains("inactive") ||
          leadsError.contains("subscription") ||
          leadsError.contains("plan");

      if (leadsTokenError) {
        setState(() {
          errorType = LeadsHomeErrorType.sessionExpired;
          errorMessage = "Your account was logged in on another device.";
          isLoading = false;
        });
        return;
      }

      if (leadsRes.statusCode != 200 && !leadsSubscriptionError) {
        setState(() {
          errorType = LeadsHomeErrorType.network;
          errorMessage = "Unable to load leads. Please try again.";
          isLoading = false;
        });
        return;
      }

      availableCount = (leadsData?["leads"] as List?)?.length ?? 0;

      setState(() {
        errorType = LeadsHomeErrorType.none;
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        errorType = LeadsHomeErrorType.network;
        errorMessage = "No internet connection. Please try again.";
        isLoading = false;
      });
    }
  }

  Future<void> _handleSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, "/login");
  }

  // Future<void> _maybeShowDisclaimer() async {
  //   if (!mounted) return;

  //   final prefs = await SharedPreferences.getInstance();

  //   // Permanent opt-out
  //   final disabled = prefs.getBool('lead_disclaimer_disabled') ?? false;
  //   if (disabled) return;

  //   final now = DateTime.now();
  //   final todayKey =
  //       "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

  //   final lastShown = prefs.getString('lead_disclaimer_last_shown');

  //   // Already shown today
  //   if (lastShown == todayKey) return;

  //   bool dontShowAgain = false;

  //   await showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) {
  //       return StatefulBuilder(
  //         builder: (context, setState) {
  //           return AlertDialog(
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(16),
  //             ),
  //             title: const Text(
  //               "Important Disclaimer",
  //               style: TextStyle(fontWeight: FontWeight.bold),
  //             ),
  //             content: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 const Text(
  //                   "Please verify whether the lead is legitimate before claiming.\n\n"
  //                   "Check the customer name, event details, and location carefully "
  //                   "to avoid fake or duplicate leads.",
  //                 ),
  //                 const SizedBox(height: 12),
  //                 Row(
  //                   children: [
  //                     Checkbox(
  //                       value: dontShowAgain,
  //                       onChanged: (value) {
  //                         setState(() {
  //                           dontShowAgain = value ?? false;
  //                         });
  //                       },
  //                     ),
  //                     const Expanded(child: Text("Do not show again")),
  //                   ],
  //                 ),
  //               ],
  //             ),
  //             actions: [
  //               ElevatedButton(
  //                 onPressed: () {
  //                   Navigator.pop(context);
  //                 },
  //                 child: const Text("OK"),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );

  //   // Save preference
  //   if (dontShowAgain) {
  //     await prefs.setBool('lead_disclaimer_disabled', true);
  //   } else {
  //     await prefs.setString('lead_disclaimer_last_shown', todayKey);
  //   }
  // }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // LOADING
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ERROR STATE
    if (errorType != LeadsHomeErrorType.none) {
      final bool isSessionExpired =
          errorType == LeadsHomeErrorType.sessionExpired;

      return Scaffold(
        appBar: AppBar(title: const Text("Leads")),
        body: AppErrorView(
          icon: isSessionExpired
              ? Icons.logout_rounded
              : Icons.wifi_off_rounded,
          title: isSessionExpired
              ? "Session Expired"
              : "No Internet Connection",
          message: errorMessage ?? "",
          buttonText: isSessionExpired ? "Login Now" : "Retry",
          onPressed: isSessionExpired ? _handleSessionExpired : _fetchCounts,
        ),
      );
    }

    // NORMAL TAB UI
    return Scaffold(
      appBar: AppBar(
        title: const Text("Leads"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Available ($availableCount)"),
            Tab(text: "My Claims ($myClaimsCount)"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AvailableLeadsPage(
            onCountChanged: (count) {
              setState(() => availableCount = count);
            },
            onClaimSuccess: () {
              setState(() => myClaimsCount += 1);
            },
          ),
          MyClaimsPage(
            onCountChanged: (count) {
              setState(() => myClaimsCount = count);
            },
          ),
        ],
      ),
    );
  }
}
