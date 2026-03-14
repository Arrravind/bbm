import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'config/api_config.dart';
import 'utils/network_utils.dart';

class MyClaimsPage extends StatefulWidget {
  final Function(int)? onCountChanged;

  const MyClaimsPage({super.key, this.onCountChanged});

  @override
  State<MyClaimsPage> createState() => _MyClaimsPageState();
}

enum ClaimsErrorType { none, network, sessionExpired, unknown }

class _MyClaimsPageState extends State<MyClaimsPage> {
  List<Map<String, dynamic>> claimedLeads = [];
  List<Map<String, dynamic>> filteredLeads = [];
  bool isLoading = true;
  String? errorMessage;
  TextEditingController searchController = TextEditingController();
  ClaimsErrorType errorType = ClaimsErrorType.none;

  late StreamSubscription<bool> _connectivitySubscription;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = NetworkUtils.onConnectivityChanged.listen((
      bool isConnected,
    ) {
      if (isConnected && !_hasInternet) {
        _fetchClaimedLeads();
      }
      if (!mounted) return;
      setState(() {
        _hasInternet = isConnected;
      });
    });
    searchController.addListener(_filterLeads);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    bool isConnected = await NetworkUtils.hasInternetConnection();
    if (!mounted) return;
    setState(() {
      _hasInternet = isConnected;
    });
    if (isConnected) {
      await _fetchClaimedLeads();
    }
  }

  void _filterLeads() {
    String query = searchController.text.toLowerCase();
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) {
        filteredLeads = claimedLeads;
      } else {
        filteredLeads = claimedLeads.where((lead) {
          String name = (lead["customer_name"] ?? "").toLowerCase();
          String status = (lead["status"] ?? "").toLowerCase();
          return name.contains(query) || status.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchClaimedLeads() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await NetworkUtils.checkConnectivity();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("auth_token");

      if (token == null) {
        if (!mounted) return;
        setState(() {
          errorType = ClaimsErrorType.sessionExpired;
          errorMessage = "Your session has expired. Please log in again.";
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiConfig.claimStatsEndpoint}?token=$token"),
      );

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}

      final String errorText =
          (data?["error"] ?? data?["message"] ?? "").toString().toLowerCase();
      final bool isTokenError = errorText.contains("token") ||
          errorText.contains("session") ||
          response.statusCode == 401;

      if (response.statusCode == 200) {
        if (isTokenError) {
          if (!mounted) return;
          setState(() {
            errorType = ClaimsErrorType.sessionExpired;
            errorMessage = "Your account was logged in on another device.";
            isLoading = false;
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          claimedLeads = List<Map<String, dynamic>>.from(
            data?["claimed_leads"] ?? [],
          );
          filteredLeads = claimedLeads;
          errorType = ClaimsErrorType.none;
          errorMessage = null;
          isLoading = false;
        });
        widget.onCountChanged?.call(claimedLeads.length);
      } else {
        if (!mounted) return;
        setState(() {
          errorType =
              isTokenError ? ClaimsErrorType.sessionExpired : ClaimsErrorType.unknown;
          errorMessage = isTokenError
              ? "Your account was logged in on another device."
              : ((data?["error"] ?? data?["message"] ?? "Unable to load claimed leads.")
                  .toString());
          isLoading = false;
        });
      }
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        errorType = ClaimsErrorType.network;
        errorMessage = e.message;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorType = ClaimsErrorType.unknown;
        errorMessage = "Something went wrong. Please try again.";
        isLoading = false;
      });
    }
  }

  Widget _buildNoInternetView() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_wifi_off, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'No Internet Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchClaimedLeads,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int myClaimsCount = claimedLeads.length;

    // NO INTERNET
    if (!_hasInternet) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: Text(
            "My Claims ($myClaimsCount)",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: _buildNoInternetView(),
      );
    }

    // LOADING
    if (isLoading) {
      return Scaffold(body: const Center(child: CircularProgressIndicator()));
    }

    // NORMAL
    return Scaffold(
      body: Padding(padding: const EdgeInsets.all(12.0), child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorType != ClaimsErrorType.none) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage ?? "Something went wrong",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            if (errorType == ClaimsErrorType.network)
              ElevatedButton.icon(
                onPressed: _fetchClaimedLeads,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),

            if (errorType == ClaimsErrorType.sessionExpired)
              ElevatedButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, "/login");
                  }
                },
                icon: const Icon(Icons.login),
                label: const Text("Login"),
              ),
          ],
        ),
      );
    }

    if (claimedLeads.isEmpty) {
      return const Center(child: Text("No claimed leads found"));
    }

    return SafeArea(
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search leads by name or status...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          // Leads list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchClaimedLeads,
              child: ListView.builder(
                itemCount: filteredLeads.length,
                itemBuilder: (context, index) {
                  final lead = filteredLeads[index];
                  return _buildLeadCard(lead: lead);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCard({required Map<String, dynamic> lead}) {
    String name = lead["customer_name"] ?? "Unknown";
    String date = lead["event_date"] ?? "";
    String status = lead["status"] ?? "new";
    // bool isReleased = lead["released"] == 1;

    Color statusColor;
    switch (status.toLowerCase()) {
      case "booked":
        statusColor = Colors.green;
        break;
      case "contacted":
        statusColor = Colors.orange;
        break;
      case "closed":
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/lead_detail', arguments: lead).then((
            _,
          ) {
            _fetchClaimedLeads();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text("Event Date: ${date.split('T').first}"),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ),

                  // if (isReleased)
                  //   Container(
                  //     padding: const EdgeInsets.symmetric(
                  //       horizontal: 8,
                  //       vertical: 4,
                  //     ),
                  //     decoration: BoxDecoration(
                  //       color: Colors.grey.shade300,
                  //       borderRadius: BorderRadius.circular(8),
                  //     ),
                  //     child: const Text(
                  //       "Released",
                  //       style: TextStyle(color: Colors.black87, fontSize: 12),
                  //     ),
                  //   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Future<void> _releaseLead(int leadId, String leadName) async {
  //   try {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     String? token = prefs.getString("auth_token");

  //     if (token == null) {
  //       if (mounted) {
  //         Navigator.pushReplacementNamed(context, "/login");
  //       }
  //       return;
  //     }

  //     final response = await http.post(
  //       Uri.parse(ApiConfig.releaseLeadEndpoint),
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({
  //         "lead_id": leadId,
  //         "token": token,
  //       }),
  //     );
  //     if(!mounted){
  //       return;
  //     }
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(data["message"])),
  //       );
  //       _fetchClaimedLeads(); // Refresh the list

  //       // Set a flag to indicate data changed (for when user eventually navigates back)
  //       SharedPreferences prefs = await SharedPreferences.getInstance();
  //       await prefs.setBool('claims_data_changed', true);
  //     } else {
  //       final error = jsonDecode(response.body);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(error["error"] ?? "Failed to release lead")),
  //       );
  //     }
  //   } catch (e) {
  //     if(!mounted){
  //       return;
  //     }
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Error: $e")),
  //     );
  //   }
  // }
}
