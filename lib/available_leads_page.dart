import 'dart:convert';
import 'meta_events.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';
import 'subscription_ended_screen.dart';

class AvailableLeadsPage extends StatefulWidget {
  final Function(int)? onCountChanged;

  final VoidCallback? onClaimSuccess;
  final bool isTelecaller;

  const AvailableLeadsPage({
    super.key,
    this.onCountChanged,
    this.onClaimSuccess,
    this.isTelecaller = false,
  });

  @override
  State<AvailableLeadsPage> createState() => _AvailableLeadsPageState();
}

enum AvailableLeadsErrorType { none, network, sessionExpired, unknown }

class _AvailableLeadsPageState extends State<AvailableLeadsPage> {
  bool _loading = true;
  bool isLoading = false;
  // final bool _sortAscending = true;
  String? _error;
  List<LeadItem> _leads = [];
  AvailableLeadsErrorType errorType = AvailableLeadsErrorType.none;

  Map<String, dynamic> uiConfig = {};
  bool uiLoaded = false;

  bool _containsAny(String source, List<String> needles) {
    final lower = source.toLowerCase();
    return needles.any(lower.contains);
  }

  String? _extractErrorMessage(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data["error"] ?? data["message"];
    if (raw == null) return null;
    final msg = raw.toString().trim();
    return msg.isEmpty ? null : msg;
  }

  bool _isTokenError(String? message) {
    if (message == null) return false;
    return _containsAny(message, [
      "token",
      "session",
      "invalid or expired token",
      "authentication token required",
      "unauthorized",
    ]);
  }

  bool _isSubscriptionError(String? message) {
    if (message == null) return false;
    return _containsAny(message, [
      "inactive",
      "subscription",
      "plan",
      "claim limit",
      "upgrade",
      "renew",
      "premium",
    ]);
  }

  Future<void> _markUserInactiveLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("status", "inactive");
    await prefs.setInt("level", 5);
  }

  Future<void> fetchUIConfig(String screen) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      final url = "${ApiConfig.uiConfigEndpoint}?screen=$screen&token=$token";

      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        setState(() {
          uiConfig = data["config"];
          uiLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("UI CONFIG ERROR: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchLeads();
    fetchUIConfig("available_leads").then((_) {
      _maybeShowDisclaimer();
    });
  }

  // void _sortLeads() {
  //   _leads.sort((a, b) {
  //     final dateA = a.eventDate != null && a.eventDate!.isNotEmpty
  //         ? DateTime.tryParse(a.eventDate!) ?? DateTime(2100)
  //         : DateTime(2100);
  //     final dateB = b.eventDate != null && b.eventDate!.isNotEmpty
  //         ? DateTime.tryParse(b.eventDate!) ?? DateTime(2100)
  //         : DateTime(2100);

  //     return _sortAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
  //   });
  // }

  Future<void> _maybeShowDisclaimer() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();

    // Permanent opt-out
    final disabled = prefs.getBool('lead_disclaimer_disabled') ?? false;
    if (disabled) return;

    final now = DateTime.now();
    final todayKey =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final lastShown = prefs.getString('lead_disclaimer_last_shown');

    // Already shown today
    if (lastShown == todayKey) return;

    bool dontShowAgain = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                uiConfig["disclaimer_title"] ?? "",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(uiConfig["disclaimer_body"] ?? ""),
                  const SizedBox(height: 12),

                  /// Checkbox + text BOTH clickable
                  InkWell(
                    onTap: () {
                      if (!mounted) return;
                      setState(() {
                        dontShowAgain = !dontShowAgain;
                      });
                    },
                    child: Row(
                      children: [
                        Checkbox(
                          value: dontShowAgain,
                          onChanged: (value) {
                            if (!mounted) return;
                            setState(() {
                              dontShowAgain = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(uiConfig["disclaimer_checkbox"] ?? ""),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(uiConfig["disclaimer_ok"] ?? "OK"),
                ),
              ],
            );
          },
        );
      },
    );

    // Save preference
    if (dontShowAgain) {
      await prefs.setBool('lead_disclaimer_disabled', true);
    } else {
      await prefs.setString('lead_disclaimer_last_shown', todayKey);
    }
  }

  Future<void> _fetchLeads() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      errorType = AvailableLeadsErrorType.none;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("auth_token");

      if (token == null) {
        if (!mounted) return;
        setState(() {
          errorType = AvailableLeadsErrorType.sessionExpired;
          _error = "Your session has expired. Please log in again.";
          _loading = false;
        });
        return;
      }

      final uri = Uri.parse("${ApiConfig.availableLeadsEndpoint}?token=$token");
      final res = await http.get(uri, headers: {"Accept": "application/json"});

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}

      final errorMessage = _extractErrorMessage(data);
      final tokenError = _isTokenError(errorMessage);
      final subscriptionError =
          _isSubscriptionError(errorMessage) ||
          (res.statusCode == 403 && errorMessage != null);

      if (res.statusCode == 200) {
        if (tokenError) {
          if (!mounted) return;
          setState(() {
            errorType = AvailableLeadsErrorType.sessionExpired;
            _error = "Your account was logged in on another device.";
            _loading = false;
          });
          return;
        }

        if (subscriptionError) {
          await _markUserInactiveLocally();
          if (!mounted) return;
          setState(() {
            errorType = AvailableLeadsErrorType.unknown;
            _error =
                errorMessage ??
                "Your subscription is inactive. Renew or upgrade to claim leads.";
            _leads = [];
            _loading = false;
          });
          widget.onCountChanged?.call(0);
          return;
        }

        final items = (data?["leads"] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final parsed = items.map(LeadItem.fromBBMJson).toList();
        if (!mounted) return;
        setState(() {
          _leads = parsed;
        });
        widget.onCountChanged?.call(_leads.length);
      } else {
        if (!mounted) return;
        if (tokenError || res.statusCode == 401) {
          setState(() {
            errorType = AvailableLeadsErrorType.sessionExpired;
            _error = "Your account was logged in on another device.";
            _loading = false;
          });
          return;
        }

        if (subscriptionError) {
          await _markUserInactiveLocally();
          setState(() {
            errorType = AvailableLeadsErrorType.unknown;
            _error =
                errorMessage ??
                "Your subscription is inactive. Renew or upgrade to claim leads.";
            _leads = [];
            _loading = false;
          });
          widget.onCountChanged?.call(0);
          return;
        }

        setState(() {
          errorType = AvailableLeadsErrorType.unknown;
          _error = errorMessage ?? "Unable to load leads right now.";
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorType = AvailableLeadsErrorType.network;
        _error = "No internet connection. Please try again.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // final int availableCount = _leads.length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchLeads,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),

                if (errorType == AvailableLeadsErrorType.network)
                  ElevatedButton.icon(
                    onPressed: _fetchLeads,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                  ),

                if (errorType == AvailableLeadsErrorType.sessionExpired)
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
          ),
        ],
      );
    }

    if (_leads.isEmpty) {
      return ListView(
        children: const [
          Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("No leads available"),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: _leads.length,
      itemBuilder: (context, index) {
        final lead = _leads[index];
        return _buildLeadCard(lead: lead);
      },
    );
  }

  void _openLead(LeadItem lead) {
    Navigator.pushNamed(context, '/lead_detail', arguments: lead).then((_) {
      _fetchLeads();
    });
  }

  Future<void> _confirmClaimPopup(LeadItem lead) async {
    if (!mounted) return;
    if (widget.isTelecaller) {
      _openLead(lead);
      return;
    }

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Confirm Claim"),
          content: const Text(
            "Are you sure you want to claim this lead?\n\n"
            "Once claimed, it will move to My Claims.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Claim"),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _claimLead(lead);
    }
  }

  Widget _buildLeadCard({required LeadItem lead}) {
    // final Color statusColor = _statusToColor(lead.status);

    bool isLocked = lead.lockedUntil != null && lead.lockedUntil!.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with name + status
            Row(
              children: [
                Text(
                  lead.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                // Chip(
                //   label: Text(
                //     _titleCase(lead.status),
                //     style: TextStyle(
                //       color: Colors.white,
                //       fontSize: 12,
                //       fontWeight: FontWeight.bold,
                //     ),
                //   ),
                //   backgroundColor: statusColor,
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 8,
                //     vertical: 0,
                //   ),
                // ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🧩 Responsive left side (lead details)
                Flexible(
                  fit: FlexFit.tight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double baseWidth = constraints.maxWidth;
                        double fontSize = baseWidth < 300
                            ? 12
                            : 14; // Dynamic font size

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "📍 Location: ${lead.location.isEmpty ? '-' : lead.location}",
                              softWrap: true,
                              style: TextStyle(fontSize: fontSize),
                            ),
                            Text(
                              "📅 Event Date: ${lead.eventDate?.split('T').first ?? '-'}",
                              softWrap: true,
                              style: TextStyle(fontSize: fontSize),
                            ),
                            Text(
                              "🎉 Event Type: ${lead.eventType.isEmpty ? '-' : lead.eventType}",
                              softWrap: true,
                              style: TextStyle(fontSize: fontSize),
                            ),
                            if (lead.budgetRange.isNotEmpty)
                              Text(
                                "💰 Budget: ${lead.budgetRange}",
                                softWrap: true,
                                style: TextStyle(fontSize: fontSize),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // 🎯 Responsive button section
                LayoutBuilder(
                  builder: (context, constraints) {
                    double screenWidth = MediaQuery.of(context).size.width;
                    double buttonWidth = screenWidth < 350
                        ? 95
                        : screenWidth < 450
                        ? 110
                        : 130;

                    return SizedBox(
                      width: buttonWidth,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLocked
                              ? Colors.grey
                              : Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        onPressed: isLocked
                            ? null
                            : widget.isTelecaller
                            ? () => _openLead(lead)
                            : () => _confirmClaimPopup(lead),
                        child: FittedBox(
                          child: Text(
                            isLocked
                                ? "Locked"
                                : widget.isTelecaller
                                ? "Open Lead"
                                : "Claim Now",
                            style: TextStyle(
                              fontSize: screenWidth < 350 ? 12 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // const SizedBox(height: 6),
            // Text("👥 Claimed by: ${lead.claimCount}/3 MUAs"),
            // if (isLocked)
            //   Text(
            //     "🔒 Locked until: ${lead.lockedUntil}",
            //     style: const TextStyle(color: Colors.red),
            //   ),
            const SizedBox(height: 12),

            // Claim button
          ],
        ),
      ),
    );
  }

  // Color _statusToColor(String status) {
  //   switch (status.toLowerCase()) {
  //     case "new":
  //       return Colors.blue;
  //     case "booked":
  //       return Colors.green;
  //     case "contacted":
  //       return Colors.orange;
  //     case "closed":
  //       return Colors.red;
  //     case "not_interested":
  //       return Colors.grey;
  //     default:
  //       return Colors.blueGrey;
  //   }
  // }

  Future<void> _handleSubscriptionEnded() async {
    await _markUserInactiveLocally();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SubscriptionEndedScreen()),
      (route) => false,
    );
  }

  Future<void> _claimLead(LeadItem lead) async {
    if (isLoading) return; // prevent double taps
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("auth_token");
      int? level = prefs.getInt("level");
      String? status = prefs.getString("status");

      if (token == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, "/login");
        }
        return;
      }

      if (level == 5 || status == 'inactive') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Only premium users can claim leads."),
            ),
          );
        }
        return;
      }
      final response = await http.post(
        Uri.parse(ApiConfig.claimLeadEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"lead_id": lead.id, "token": token}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        if (data['success'] == true) {
          await prefs.setBool('claims_data_changed', true);
          if (!mounted) return;

          facebookAppEvents.logEvent(name: 'LeadClaimed');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lead claimed successfully!")),
          );

          widget.onClaimSuccess?.call();

          _fetchLeads(); // Refresh available leads
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Failed to claim lead')),
          );
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        String message = '';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            message = _extractErrorMessage(errorData) ?? '';
          }
        } catch (_) {}

        if (_isTokenError(message) ||
            (response.statusCode == 401 && !_isSubscriptionError(message))) {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, "/login");
          return;
        }

        await _handleSubscriptionEnded();
      } else {
        if (!mounted) return;
        String message;
        try {
          final errorData = jsonDecode(response.body);
          message = errorData['error'] ?? 'Failed to claim lead';
        } catch (_) {
          message = 'Failed to claim lead';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
        debugPrint("Error claiming lead: $e");
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // String _titleCase(String s) {
  //   if (s.isEmpty) return s;
  //   return s
  //       .split('_')
  //       .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1)))
  //       .join(' ');
  // }
}

class LeadItem {
  final int id;
  final String name;
  final String location;
  final String eventType;
  final String status;
  final String budgetRange;
  final String? eventDate;
  final int claimCount;
  final String? lockedUntil;

  LeadItem({
    required this.id,
    required this.name,
    required this.location,
    required this.eventType,
    required this.status,
    required this.budgetRange,
    required this.eventDate,
    required this.claimCount,
    required this.lockedUntil,
  });

  static LeadItem fromBBMJson(Map<String, dynamic> j) {
    return LeadItem(
      id: j["id"] as int,
      name: (j["customer_name"] as String?) ?? "Unknown",
      location: (j["location"] as String?) ?? "",
      eventType: (j["event_type"] as String?) ?? "",
      status: (j["status"] as String?) ?? "new",
      budgetRange: (j["budget_range"] as String?) ?? "",
      eventDate: j["event_date"] as String?,
      claimCount: (j["claim_count"] ?? 0) as int,
      lockedUntil: j["locked_until"] as String?,
    );
  }
}
