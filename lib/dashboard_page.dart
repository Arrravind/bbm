import 'package:bbm_app/widgets/app_error_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'config/api_config.dart';
import 'main.dart';

class DashboardPage extends StatefulWidget {
  final Function(int)? onNavigate;

  const DashboardPage({super.key, this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

enum DashboardErrorType { none, network, sessionExpired, unknown }

class _DashboardPageState extends State<DashboardPage> with RouteAware {
  String selectedFilter = "All";
  String username = "";
  String businessName = "";
  int userId = 0;

  int totalLeads = 0;
  int newLeads = 0;
  int contactedLeads = 0;
  int bookedLeads = 0;

  List<Map<String, dynamic>> recentLeads = [];
  List<Map<String, dynamic>> totalLeadsData = [];
  bool isLoading = true;
  bool _hasInternet = true;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  DashboardErrorType errorType = DashboardErrorType.none;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      if (result != ConnectivityResult.none && !_hasInternet) {
        _checkConnectivityAndLoadData();
      }
    });
  }

  Future<void> _initConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      if (!mounted) return;
      _hasInternet = connectivityResult != ConnectivityResult.none;
    });
    if (_hasInternet) {
      await _loadUserData();
    }
  }

  Future<void> _checkConnectivityAndLoadData() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      setState(() {
        if (!mounted) return;
        _hasInternet = true;
        isLoading = true;
      });
      await _loadUserData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? "";
    if (currentRoute != "/settings") {
      _fetchClaimedLeads();
    }
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt("user_id") ?? 0;
    username = prefs.getString("username") ?? "";
    businessName = prefs.getString("business_name") ?? "";
    if (userId != 0) {
      await _fetchClaimedLeads();
    } else {
      setState(() {
        if (!mounted) return;
        isLoading = false;
      });
    }
  }

  Future<void> _fetchClaimedLeads() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("auth_token");

      if (token == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, "/login");
        }
        return;
      }

      var url = Uri.parse("${ApiConfig.claimStatsEndpoint}?token=$token");
      var response = await http.get(url);
      debugPrint(
        "Debug : Dashboard API Response: ${response.statusCode} - ${response.body}",
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        if (data["success"] == true) {
          setState(() {
            if (!mounted) return;
            totalLeads = data["total_allowed"] ?? 0;
            newLeads = data["claimed"] ?? 0;
            contactedLeads = data["balance"] ?? 0;
            bookedLeads = data["booked_claims"] ?? 0;
            recentLeads = List<Map<String, dynamic>>.from(
              data["recent_leads"] ?? [],
            );
            totalLeadsData = List<Map<String, dynamic>>.from(
              data["claimed_leads"] ?? [],
            );
            isLoading = false;
          });

          errorType = DashboardErrorType.none;
          errorMessage = null;
        } else {
          setState(() {
            if (!mounted) return;
            isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          if (!mounted) return;
          errorType = DashboardErrorType.sessionExpired;
          errorMessage =
              "Your account was logged in on another device. Please login again.";
          isLoading = false;
        });
        return;
      } else {
        setState(() {
          if (!mounted) return;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        if (!mounted) return;
        errorType = DashboardErrorType.network;
        errorMessage =
            "No internet connection. Please check your network and try again.";
        isLoading = false;
      });
    }
  }

  // Widget _buildNoInternetView() {
  //   return Center(
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         const Icon(Icons.signal_wifi_off, size: 80, color: Colors.grey),
  //         const SizedBox(height: 20),
  //         const Text(
  //           'No Internet Connection',
  //           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //         ),
  //         const SizedBox(height: 10),
  //         const Text(
  //           'Please check your internet connection and try again.',
  //           textAlign: TextAlign.center,
  //           style: TextStyle(fontSize: 16),
  //         ),
  //         const SizedBox(height: 20),
  //         ElevatedButton.icon(
  //           onPressed: _checkConnectivityAndLoadData,
  //           icon: const Icon(Icons.refresh),
  //           label: const Text('Retry'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _handleSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, "/login");
  }

  Future<bool> _onBackPressed() async {
    bool exit = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit BBM?"),
        content: const Text("Do you want to exit the app?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Exit"),
          ),
        ],
      ),
    );

    return exit;
  }

  @override
  Widget build(BuildContext context) {
    // ---------- NO INTERNET ----------
    if (!_hasInternet) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          automaticallyImplyLeading: false,
        ),
        body: AppErrorView(
          icon: Icons.wifi_off_rounded,
          title: "No Internet Connection",
          message: "Please check your internet connection and try again.",
          buttonText: "Retry",
          onPressed: _checkConnectivityAndLoadData,
        ),
      );
    }

    // ---------- LOADING ----------
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ---------- ERROR STATES ----------
    if (errorType != DashboardErrorType.none) {
      final bool isSessionExpired =
          errorType == DashboardErrorType.sessionExpired;

      return Scaffold(
        appBar: AppBar(
          title: const Text("Dashboard"),
          automaticallyImplyLeading: false,
        ),
        body: AppErrorView(
          icon: isSessionExpired
              ? Icons.logout_rounded
              : Icons.wifi_off_rounded,
          title: isSessionExpired ? "Session Expired" : "Connection Problem",
          message:
              errorMessage ??
              (isSessionExpired
                  ? "Your account was logged in on another device.\nPlease login again to continue."
                  : "Unable to connect. Please try again."),
          buttonText: isSessionExpired ? "Login Now" : "Retry",
          onPressed: isSessionExpired
              ? _handleSessionExpired
              : _checkConnectivityAndLoadData,
        ),
      );
    }

    // ---------- NORMAL DASHBOARD ----------
    List<Map<String, dynamic>> filteredLeads = selectedFilter == "All"
        ? totalLeadsData
        : totalLeadsData
              .where(
                (lead) =>
                    lead["status"].toString().toLowerCase() ==
                    selectedFilter.toLowerCase(),
              )
              .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onBackPressed();
      },
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchClaimedLeads,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome back, $businessName",
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // ---------- STATS ----------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard(
                        Icons.list,
                        "Total",
                        totalLeads.toString(),
                        Colors.blue,
                      ),
                      _buildStatCard(
                        Icons.star,
                        "Claimed",
                        newLeads.toString(),
                        Colors.purple,
                      ),
                      _buildStatCard(
                        Icons.account_balance_wallet,
                        "Balance",
                        contactedLeads.toString(),
                        Colors.orange,
                      ),
                      _buildStatCard(
                        Icons.check_circle,
                        "Booked",
                        bookedLeads.toString(),
                        Colors.green,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ---------- AVAILABLE LEADS BUTTON ----------
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    icon: const Icon(Icons.work),
                    label: const Text("Go to Available Leads"),
                    onPressed: () async {
                      widget.onNavigate?.call(1);
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      bool changed =
                          prefs.getBool('claims_data_changed') ?? false;
                      if (changed) {
                        _fetchClaimedLeads();
                        await prefs.setBool('claims_data_changed', false);
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // ---------- RECENT LEADS HEADER ----------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recent Claimed Leads",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<String>(
                        value: selectedFilter,
                        items: ["All", "New", "Contacted", "Booked"]
                            .map(
                              (filter) => DropdownMenuItem(
                                value: filter,
                                child: Text(filter),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            if (!mounted) return;
                            selectedFilter = value!;
                          });
                        },
                      ),
                    ],
                  ),

                  // ---------- RECENT LEADS LIST ----------
                  Column(
                    children: filteredLeads.take(5).map((lead) {
                      return _buildLeadCard(
                        lead["customer_name"] ?? lead["name"] ?? "Unknown",
                        lead["event_date"] ?? lead["date"] ?? "",
                        lead["status"] ?? "new",
                      );
                    }).toList(),
                  ),

                  // ---------- VIEW ALL ----------
                  if (filteredLeads.length > 5)
                    TextButton(
                      onPressed: () async {
                        widget.onNavigate?.call(2);
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setBool('claims_data_changed', false);
                      },
                      child: const Text("View All Leads"),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String title,
    String count,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              count,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadCard(String name, String date, String status) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case "booked":
        statusColor = Colors.green;
        break;
      case "contacted":
        statusColor = Colors.orange;
        break;
      case "new":
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(
          name.isNotEmpty ? name : "Unknown",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          date.isNotEmpty ? "Function Date: $date" : "Date not available",
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status.isNotEmpty ? status : "Unknown",
            style: TextStyle(color: statusColor, fontSize: 12),
          ),
        ),
        onTap: () {
          widget.onNavigate?.call(2);
        },
      ),
    );
  }
}
