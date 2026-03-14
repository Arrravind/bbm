import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../theme/bbm_theme.dart';

class TelecallerDashboardPage extends StatefulWidget {
  const TelecallerDashboardPage({super.key});

  @override
  State<TelecallerDashboardPage> createState() =>
      _TelecallerDashboardPageState();
}

class _TelecallerDashboardPageState extends State<TelecallerDashboardPage> {
  bool isLoading = true;

  int totalContacted = 0;
  int callsToday = 0;
  int notesAdded = 0;
  int interestedLeads = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      if (token == null) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiConfig.telecallerDashboardEndpoint}?token=$token"),
      );

      final data = jsonDecode(response.body);

      debugPrint("Debug: Dashboard data: $data");

      if (!mounted) return;

      setState(() {
        if (data["success"] == true) {
          totalContacted = data["total_contacted"] ?? 0;
          callsToday = data["calls_today"] ?? 0;
          notesAdded = data["notes_added"] ?? 0;
          interestedLeads = data["interested_leads"] ?? 0;
        }

        isLoading = false;
      });
    } catch (e) {
      debugPrint("Dashboard error: $e");

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: BBMTheme.primaryLight,

      body: RefreshIndicator(
        onRefresh: _fetchDashboard,

        child: ListView(
          padding: const EdgeInsets.all(16),

          children: [
            const SizedBox(height: 10),

            const SizedBox(height: 20),

            Row(
              children: [
                _statCard(
                  title: "Leads Contacted",
                  value: totalContacted,
                  icon: Icons.people_alt,
                  color: Colors.blue,
                ),

                _statCard(
                  title: "Calls Today",
                  value: callsToday,
                  icon: Icons.call,
                  color: Colors.green,
                ),
              ],
            ),

            Row(
              children: [
                _statCard(
                  title: "Notes Added",
                  value: notesAdded,
                  icon: Icons.note,
                  color: Colors.orange,
                ),

                _statCard(
                  title: "Interested Leads",
                  value: interestedLeads,
                  icon: Icons.thumb_up,
                  color: Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 20),

            _activitySummary(),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6),

        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BBMTheme.border),
        ),

        child: Column(
          children: [
            Icon(icon, color: color, size: 28),

            const SizedBox(height: 12),

            Text(
              value.toString(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activitySummary() {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BBMTheme.border),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            "Today's Activity",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          _activityRow("Calls Made", callsToday),

          _activityRow("Notes Written", notesAdded),

          _activityRow("Interested Customers", interestedLeads),
        ],
      ),
    );
  }

  Widget _activityRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),

      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),

          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
