import 'package:flutter/material.dart';
import 'theme/bbm_theme.dart';

class LeadNotesPage extends StatelessWidget {
  final List notes;

  const LeadNotesPage({super.key, required this.notes});

  String _formatDateTime(String dateTimeStr) {
    if (dateTimeStr.isEmpty) return "N/A";

    try {
      final dt = DateTime.parse(dateTimeStr);

      String day = dt.day.toString().padLeft(2, '0');
      String month = dt.month.toString().padLeft(2, '0');
      String year = dt.year.toString();

      int hour = dt.hour;
      int minute = dt.minute;

      String period = hour >= 12 ? "PM" : "AM";

      hour = hour % 12;
      if (hour == 0) hour = 12;

      String hourStr = hour.toString().padLeft(2, '0');
      String minuteStr = minute.toString().padLeft(2, '0');

      return "$day/$month/$year  $hourStr:$minuteStr $period";
    } catch (e) {
      return dateTimeStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "new":
        return Colors.blue;
      case "contacted":
        return Colors.orange;
      case "booked":
        return Colors.green;
      case "closed":
        return Colors.grey;
      case "not answered":
        return Colors.red;
      case "busy":
        return Colors.deepOrange;
      default:
        return BBMTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedNotes = List<Map<String, dynamic>>.from(notes)
      ..sort(
        (a, b) => DateTime.parse(
          b['created_at'],
        ).compareTo(DateTime.parse(a['created_at'])),
      );

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Notes"),
        backgroundColor: BBMTheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: sortedNotes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_alt_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    "No notes added yet",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Notes you add will appear here",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedNotes.length,
              itemBuilder: (_, index) {
                final note = sortedNotes[index];

                final String status = note["status"] ?? "";

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),

                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BBMTheme.border),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (status.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),

                          margin: const EdgeInsets.only(bottom: 8),

                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            borderRadius: BorderRadius.circular(6),
                          ),

                          child: Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      if ((note["note"] ?? "").isNotEmpty)
                        Text(
                          note["note"],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                      const SizedBox(height: 6),

                      Text(
                        _formatDateTime(note["created_at"] ?? ""),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
