import 'package:bbm_app/available_leads_page.dart';
import 'package:bbm_app/widgets/app_error_view.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'theme/bbm_theme.dart';
import 'lead_notes_page.dart';

class LeadDetailPage extends StatefulWidget {
  const LeadDetailPage({super.key});

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends State<LeadDetailPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? lead;
  String selectedStatus = 'new';
  bool isUpdating = false;
  bool isLoadingLead = false;
  bool isUserInactive = false;
  bool isCheckingStatus = true;
  bool isTelecaller = false;

  bool callInitiated = false;

  final TextEditingController followupNotesController = TextEditingController();

  final TextEditingController manualNotesController = TextEditingController();

  List<String> statusOptions = [];

  List<String> followupOptions = [];
  String? followupStatus;
  bool isLoadingStatuses = true;

  List artists = [];
  int? selectedArtistId;
  bool isLoadingArtists = false;

  Future<void> _checkUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString("status");
    final role = prefs.getString("role");

    if (!mounted) return;

    setState(() {
      isUserInactive = status != null && status.toLowerCase() == "inactive";
      isCheckingStatus = false;
      isTelecaller = role == "telecaller";
      statusOptions = isTelecaller
          ? [
              'new',
              'booked',
              'contacted',
              'interested',
              'not_interested',
              'call_later',
            ]
          : ['new', 'contacted', 'booked', 'closed'];
    });
  }

  Future<void> _fetchArtists() async {
    setState(() {
      isLoadingArtists = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      final res = await http.get(
        Uri.parse("${ApiConfig.eliteArtistsEndpoint}?token=$token"),
      );

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        setState(() {
          artists = data["artists"];
        });
      }
    } catch (e) {
      debugPrint("Artist fetch error: $e");
    } finally {
      setState(() {
        isLoadingArtists = false;
      });
    }
  }

  Future<void> _assignArtistApi() async {
    if (selectedArtistId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    final res = await http.post(
      Uri.parse(ApiConfig.assignArtistEndpoint),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "lead_id": lead!['id'],
        "artist_id": selectedArtistId,
        "token": token,
      }),
    );

    final data = jsonDecode(res.body);

    debugPrint("Debug : Assign artist response: $data");
    if (!mounted) return;

    if (data["success"] == true) {
      Navigator.pop(context);

      await _refreshLead();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Artist assigned successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["error"] ?? "Assignment failed")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkUserStatus();
    fetchFollowupStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    followupNotesController.dispose();
    manualNotesController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && callInitiated) {
      callInitiated = false;
      _showFollowupDialog();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args != null && lead == null && !isLoadingLead) {
      if (args is Map<String, dynamic>) {
        _fetchLeadDetails(args['id']);
      }

      if (args is LeadItem) {
        _fetchLeadDetails(args.id);
      }
    }
  }

  Future<void> fetchFollowupStatuses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      if (token == null || token.isEmpty) {
        debugPrint("Debug : Token missing");
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiConfig.getFollowupStatusEndpoint}?token=$token"),
      );

      final data = jsonDecode(response.body);

      debugPrint("Debug : Follow-up statuses response: $data");

      if (data['success'] == true) {
        setState(() {
          followupOptions = List<String>.from(data['statuses']);
          followupStatus = followupOptions.isNotEmpty
              ? followupOptions.first
              : null;
          isLoadingStatuses = false;
        });
      }
    } catch (e) {
      debugPrint("Debug : Fetch followup error: $e");

      setState(() {
        isLoadingStatuses = false;
      });
    }
  }

  Future<void> _fetchLeadDetails(int leadId) async {
    setState(() {
      lead = null;
      isUpdating = false;
      isLoadingLead = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      String? token = prefs.getString("auth_token");

      if (!mounted) return;

      if (token == null) {
        Navigator.pushReplacementNamed(context, "/login");
        return;
      }

      final response = await http.get(
        Uri.parse(
          "${ApiConfig.leadDetailsEndpoint}?token=$token&lead_id=$leadId",
        ),
      );

      // debugPrint("Debug : Lead details response: ${response.body}");

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        setState(() {
          lead = data['lead'];
          selectedStatus = lead!['status'] ?? statusOptions.first;
          isLoadingLead = false;
        });
      } else {
        setState(() {
          isLoadingLead = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingLead = false;
      });
    }
  }

  Future<void> openDialer(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');

    callInitiated = true;

    await launchUrlString("tel:$cleaned", mode: LaunchMode.externalApplication);
  }

  Future<void> openWhatsApp(String phone, BuildContext context) async {
    const countryCode = "91";
    final fullPhone = countryCode + phone.replaceAll(RegExp(r'\D'), '');

    await launchUrlString(
      "https://wa.me/$fullPhone",
      mode: LaunchMode.externalApplication,
    );
  }

  void _showFollowupDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Call Follow-up"),
        content: isLoadingStatuses
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: followupStatus,
                    items: followupOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        followupStatus = value;
                      });
                    },
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: followupNotesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Notes",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(onPressed: _saveFollowup, child: const Text("Save")),
        ],
      ),
    );
  }

  void _showManualNoteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Note"),
        content: TextField(
          controller: manualNotesController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: "Enter note here",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(onPressed: _saveManualNote, child: const Text("Save")),
        ],
      ),
    );
  }

  Future<void> _saveFollowup() async {
    final note = followupNotesController.text.trim();

    if (followupStatus == null && note.isEmpty) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String token = prefs.getString("auth_token")!;

    final response = await http.post(
      Uri.parse(ApiConfig.addNewNoteEndpoint),

      headers: {"Content-Type": "application/json"},

      body: jsonEncode({
        "lead_id": lead!['id'],
        "note": note,
        "status": followupStatus,
        "token": token,
      }),
    );

    final data = jsonDecode(response.body);

    debugPrint("Debug : Follow-up save response: $data");

    if (data["success"] == true) {
      _prependLocalNote(note, followupStatus);

      setState(() {
        lead!['status'] = selectedStatus;
      });

      followupNotesController.clear();

      if (!mounted) return;

      Navigator.pop(context);

      await _refreshLead();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Follow-up saved (${followupStatus?.toUpperCase()})"),
        ),
      );
    }
  }

  void _assignArtist() async {
    await _fetchArtists();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Assign Artist"),
        content: isLoadingArtists
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : DropdownButtonFormField<int>(
                hint: const Text("Select Artist"),
                value: selectedArtistId,
                items: artists.map<DropdownMenuItem<int>>((artist) {
                  return DropdownMenuItem<int>(
                    value: artist["id"],
                    child: Text(
                      "${artist["name"]} (${artist["location"] ?? ""})",
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedArtistId = value;
                  });
                },
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: _assignArtistApi,
            child: const Text("Assign"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveManualNote() async {
    final note = manualNotesController.text.trim();

    if (note.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Note cannot be empty")));
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String token = prefs.getString("auth_token")!;

    final response = await http.post(
      Uri.parse(ApiConfig.addNewNoteEndpoint),

      headers: {"Content-Type": "application/json"},

      body: jsonEncode({"lead_id": lead!['id'], "note": note, "token": token}),
    );

    final data = jsonDecode(response.body);

    if (data["success"] == true) {
      _prependLocalNote(note, "");
      manualNotesController.clear();

      if (!mounted) return;

      Navigator.pop(context);

      await _refreshLead();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Note added successfully")));
    }
  }

  void _prependLocalNote(String noteText, String? status) {
    final now = DateTime.now().toIso8601String();

    final newNote = {"note": noteText, "status": status, "created_at": now};

    setState(() {
      final currentNotes = List<Map<String, dynamic>>.from(
        lead!['notes'] ?? [],
      );

      currentNotes.insert(0, newNote);

      lead!['notes'] = currentNotes;
    });
  }

  Future<void> _updateStatus() async {
    if (selectedStatus == lead!['status']) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Status already updated")));

      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      String? token = prefs.getString("auth_token");

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session expired. Please login again.")),
        );

        Navigator.pushReplacementNamed(context, "/login");

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

      // Check empty response
      if (response.body.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server returned empty response")),
        );

        return;
      }

      final dynamic decoded = jsonDecode(response.body);

      debugPrint("Debug : Status update response: $decoded");

      if (decoded is Map<String, dynamic>) {
        // SUCCESS CASE
        if (decoded["success"] == true) {
          setState(() {
            lead!['status'] = selectedStatus;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                decoded["message"] ?? "Status updated successfully",
              ),
            ),
          );
        }
        // TOKEN ERROR CASE
        else if (decoded["error"]?.toString().toLowerCase().contains("token") ==
            true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Session expired. Please login again."),
            ),
          );

          await prefs.remove("auth_token");
          if (!mounted) return;

          Navigator.pushReplacementNamed(context, "/login");
        }
        // OTHER SERVER ERROR
        else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(decoded["error"] ?? "Failed to update status"),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid server response")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error. Please try again.")),
      );

      debugPrint("Debug : Update Status Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCheckingStatus) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isLoadingLead) {
      return Scaffold(
        backgroundColor: BBMTheme.primaryLight,
        appBar: AppBar(backgroundColor: BBMTheme.primary),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (lead == null) {
      return Scaffold(
        backgroundColor: BBMTheme.primaryLight,
        body: AppErrorView(
          icon: Icons.error,
          title: "Unable to Load Lead",
          message: "Try again later",
          buttonText: "Retry",
          onPressed: _refreshLead,
        ),
      );
    }

    return Scaffold(
      backgroundColor: BBMTheme.primaryLight,

      appBar: AppBar(
        title: Text("Lead Details"),
        backgroundColor: BBMTheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BBMTheme.primary,
        onPressed: _showManualNoteDialog,
        icon: const Icon(Icons.note_add, color: Colors.white),
        label: const Text("Add Note", style: TextStyle(color: Colors.white)),
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshLead,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),

            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),

            child: Column(
              children: [
                _buildHeader(),
                // _buildContactCard(),
                _buildEventCard(),

                _buildAdditionalCard(),

                _buildNotesPreviewCard(),

                _buildStatusCard(),

                _buildUpdateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return _modernCard(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: BBMTheme.primaryLight,
                child: Text(
                  lead!['customer_name'][0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: BBMTheme.primary,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead!['customer_name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              if (lead?['assigned_artist_name'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "Assigned Artist: ${lead!['assigned_artist_name']}",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: BBMTheme.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lead!['status'].toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: BBMTheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Call + WhatsApp buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => openDialer(lead!['phone']),
                  icon: const Icon(Icons.call, color: Colors.white),
                  label: const Text(
                    "Call",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BBMTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => openWhatsApp(lead!['phone'], context),
                  icon: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "WhatsApp",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Assign Artist button (telecaller only)
          if (isTelecaller) ...[
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _assignArtist,
                icon: Icon(
                  lead?['assigned_artist_id'] == null
                      ? Icons.person_add
                      : Icons.swap_horiz,
                  color: Colors.white,
                ),
                label: Text(
                  lead?['assigned_artist_id'] == null
                      ? "Assign Artist"
                      : "Reassign Artist",
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    if (dateTimeStr.isEmpty) return "N/A";

    try {
      DateTime dt = DateTime.parse(dateTimeStr);

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

  // Widget _buildContactCard() {
  //   return _modernCard(
  //     title: "Contact Information",

  //     child: Column(
  //       children: [
  //         _infoTile(Icons.phone, lead!['phone']),

  //         _infoTile(Icons.calendar_today, _formatDate(lead!['claim_time'])),
  //       ],
  //     ),
  //   );
  // }

  Widget _noteTile(Map note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: double.infinity,
      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: BBMTheme.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((note["status"] ?? "").isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 6),

              decoration: BoxDecoration(
                color: BBMTheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),

              child: Text(
                note["status"].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if ((note["note"] ?? "").isNotEmpty) Text(note["note"]),

          const SizedBox(height: 4),

          Text(
            _formatDateTime(note["created_at"]),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesPreviewCard() {
    final List notes = lead!['notes'] ?? [];

    return _modernCard(
      title: "Notes",

      child: Column(
        children: [
          if (notes.isEmpty)
            const Text(
              "No notes added yet",
              style: TextStyle(color: Colors.grey),
            ),

          if (notes.isNotEmpty)
            ...notes.take(2).map((note) {
              return _noteTile(note);
            }),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,

            child: TextButton(
              onPressed: _openNotesPage,

              child: const Text("View All Notes"),
            ),
          ),
        ],
      ),
    );
  }

  void _openNotesPage() {
    if (lead == null) return;

    final List notes = lead!['notes'] ?? [];

    Navigator.push(
      context,

      MaterialPageRoute(builder: (context) => LeadNotesPage(notes: notes)),
    );
  }

  Widget _buildEventCard() {
    return _modernCard(
      title: "Event Details",

      child: Column(
        children: [
          _infoTile(Icons.event, _formatDate(lead!['event_date'])),

          _infoTile(Icons.category, lead!['event_type']),

          _infoTile(Icons.location_on, lead!['venue']),
        ],
      ),
    );
  }

  Widget _buildAdditionalCard() {
    return _modernCard(
      title: "Additional Information",

      child: Text(lead!['requirements'] ?? "None"),
    );
  }

  Widget _buildStatusCard() {
    return _modernCard(
      title: "Lead Status",

      child: DropdownButtonFormField(
        value: statusOptions.contains(selectedStatus)
            ? selectedStatus
            : statusOptions.first,

        items: statusOptions
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),

        onChanged: (value) {
          setState(() {
            selectedStatus = value.toString();
          });
        },
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,

      child: ElevatedButton(
        onPressed: isUpdating ? null : _updateStatus,

        style: ElevatedButton.styleFrom(
          backgroundColor: BBMTheme.primary,
          padding: const EdgeInsets.all(14),
        ),

        child: isUpdating
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "Update Status",
                style: TextStyle(color: Colors.white),
              ),
      ),
    );
  }

  Widget _modernCard({String? title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),

      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: BBMTheme.border),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          if (title != null)
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

          if (title != null) const SizedBox(height: 10),

          child,
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),

      child: Row(
        children: [
          Icon(icon, color: BBMTheme.primary),

          const SizedBox(width: 10),

          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "N/A";

    DateTime date = DateTime.parse(dateStr);

    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _refreshLead() async {
    final args = ModalRoute.of(context)?.settings.arguments;

    int? leadId;

    if (args is Map<String, dynamic>) {
      leadId = args['id'];
    } else if (args is LeadItem) {
      leadId = args.id;
    } else {
      leadId = lead?['id'];
    }

    if (leadId == null) return;

    await _fetchLeadDetails(leadId);
  }
}
