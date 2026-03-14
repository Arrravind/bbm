import 'package:bbm_app/widgets/app_error_view.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LeadDetailPage extends StatefulWidget {
  const LeadDetailPage({super.key});

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends State<LeadDetailPage> {
  Map<String, dynamic>? lead;
  String selectedStatus = 'new';
  bool isUpdating = false;
  bool isLoadingLead = false;
  bool isUserInactive = false;
  bool isCheckingStatus = true;

  final List<String> statusOptions = ['new', 'contacted', 'booked', 'closed'];

  Future<void> _checkUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString("status");

    if (!mounted) return;

    setState(() {
      isUserInactive = status != null && status.toLowerCase() == "inactive";
      isCheckingStatus = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (isUserInactive) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null && lead == null && !isLoadingLead) {
      _fetchLeadDetails(args['id']);
    }
  }

  Future<void> _fetchLeadDetails(int leadId) async {
    if (isUserInactive) {
      return;
    }
    setState(() {
      lead = null;
      isUpdating = false;
      isLoadingLead = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("auth_token");

      if (token == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, "/login");
        }
        return;
      }

      final response = await http.get(
        Uri.parse(
          "${ApiConfig.leadDetailsEndpoint}?token=$token&lead_id=$leadId",
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Check for error in API response (invalid/expired token)
        if (data is Map<String, dynamic> &&
            data.containsKey("error") &&
            (data["error"]?.toString().toLowerCase().contains("token") ??
                false)) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, "/login");
          }
          return;
        }
        if (data['success'] == true) {
          setState(() {
            lead = data['lead'];
            selectedStatus = lead!['status'] ?? 'new';
            isLoadingLead = false;
          });
        } else {
          setState(() {
            isLoadingLead = false;
          });
          if (!isUserInactive && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Unable to fetch lead")),
            );
          }
        }
      } else {
        if (!isUserInactive && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Unable to fetch lead")));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> openWhatsApp(String phone, BuildContext context) async {
    const countryCode = "91";
    final fullPhone = countryCode + phone.replaceAll(RegExp(r'\D'), '');
    final url = "https://wa.me/$fullPhone";
    final messenger = ScaffoldMessenger.of(context);

    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text("Could not open WhatsApp: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ---------- CHECKING STATUS ----------
    if (isCheckingStatus) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ---------- USER INACTIVE (SUBSCRIPTION ENDED) ----------
    // if (isUserInactive) {
    //   return Scaffold(
    //     appBar: AppBar(
    //       title: const Text("Lead Details"),
    //       backgroundColor: Colors.deepPurple,
    //       foregroundColor: Colors.white,
    //       automaticallyImplyLeading: true,
    //     ),
    //     body: AppErrorView(
    //       icon: Icons.lock_outline_rounded,
    //       title: "Subscription Ended",
    //       message:
    //           "Your subscription has ended.\n\n"
    //           "Subscribe to view your claimed leads’ details and to claim more leads.",
    //       buttonText: "Subscribe Now",
    //       onPressed: () {
    //         Navigator.pushReplacementNamed(context, "/Subscription");
    //       },
    //     ),
    //   );
    // }

    // ---------- LOADING LEAD ----------
    if (isLoadingLead) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Lead Details"),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ---------- NO LEAD ----------
    if (lead == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Lead Details"),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: AppErrorView(
          icon: Icons.error_outline,
          title: "Unable to Load Lead",
          message:
              "We couldn’t fetch the lead details.\nPlease try again later.",
          buttonText: "Retry",
          onPressed: _refreshLead,
        ),
      );
    }

    // ---------- NORMAL LEAD DETAILS UI ----------
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(lead!['customer_name'] ?? 'Lead Details'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshLead,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderSection(),
            _buildLeadInfo(),
            _buildStatusSection(),
            _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.deepPurple, Colors.deepPurple.shade300],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.person_outline,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              lead!['customer_name'] ?? 'Unknown Customer',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(selectedStatus).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                selectedStatus.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(
            "Contact Information",
            Icons.contact_phone,
            Colors.blue,
            [
              _buildWhatsAppTile(lead!['phone'] ?? ''),
              _buildInfoTile(
                Icons.calendar_today,
                "Claimed Date",
                _formatDate(lead!['claim_time'] ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard("Event Details", Icons.event, Colors.orange, [
            _buildInfoTile(
              Icons.calendar_today,
              "Event Date",
              _formatDate(lead!['event_date'] ?? ''),
            ),
            _buildInfoTile(
              Icons.category,
              "Event Type",
              lead!['event_type'] ?? 'N/A',
            ),
            _buildInfoTile(Icons.location_on, "Venue", lead!['venue'] ?? 'N/A'),
            // _buildInfoTile(
            //   Icons.group,
            //   "Guest Count",
            //   lead!['guest_count']?.toString() ?? 'N/A',
            // ),
          ]),
          const SizedBox(height: 16),
          _buildInfoCard("Additional Info", Icons.description, Colors.blue, [
            _buildInfoTile(
              Icons.description,
              "Additional Info",
              lead!['requirements'] ?? 'N/A',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildWhatsAppTile(String phoneNumber) {
    return GestureDetector(
      onTap: () {
        if (phoneNumber.isNotEmpty) {
          openWhatsApp(phoneNumber, context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 2),
              child: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Click Here To Chat",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Card(
      elevation: 8,
      shadowColor: color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, color.withValues(alpha: 0.05)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 8,
        shadowColor: Colors.deepPurple.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.deepPurple.withValues(alpha: 0.05)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_note,
                        color: Colors.deepPurple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Update Status",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.grey.shade50,
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Lead Status',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: statusOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _getStatusColor(
                                      status,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.deepPurple.shade400],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: isUpdating ? null : _updateStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isUpdating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Updating...",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.update, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Update Status",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return Colors.green;
      case 'contacted':
        return Colors.orange;
      case 'closed':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateStr);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _updateStatus() async {
    if (selectedStatus == lead!['status']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Status is already up to date")),
      );
      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("auth_token");

      if (token == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, "/login");
        }
        return;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.updateStatusEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lead_id": lead!['id'],
          "status": selectedStatus,
          "token": token,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            lead!['status'] = selectedStatus;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Status updated to ${selectedStatus.toUpperCase()}",
              ),
            ),
          );
          await prefs.setBool('claims_data_changed', true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Failed to update status')),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update status')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Future<void> _refreshLead() async {
    if (lead != null) {
      await _fetchLeadDetails(lead!['id']);
    }
  }
}
