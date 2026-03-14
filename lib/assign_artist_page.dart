import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class AssignArtistPage extends StatefulWidget {
  const AssignArtistPage({super.key});

  @override
  State<AssignArtistPage> createState() => _AssignArtistPageState();
}

class _AssignArtistPageState extends State<AssignArtistPage> {
  bool isLoading = true;
  bool assigning = false;

  List artists = [];
  int? selectedArtist;

  int? leadId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    leadId = args?["id"];

    _fetchArtists();
  }

  Future<void> _fetchArtists() async {
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
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Artist fetch error: $e");

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _assignArtist() async {
    if (selectedArtist == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select an artist")));
      return;
    }

    setState(() {
      assigning = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      final res = await http.post(
        Uri.parse(ApiConfig.assignArtistEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lead_id": leadId,
          "artist_id": selectedArtist,
          "token": token,
        }),
      );

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Artist assigned successfully")),
        );

        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["error"] ?? "Assignment failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() {
          assigning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Assign Artist"), centerTitle: true),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),

              children: [
                const Text(
                  "Select an Artist",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 16),

                ...artists.map((artist) {
                  final id = artist["id"];
                  final name = artist["name"];

                  return Card(
                    child: RadioListTile(
                      value: id,
                      groupValue: selectedArtist,

                      title: Text(name),

                      subtitle: Text(artist["location"] ?? ""),

                      onChanged: (value) {
                        setState(() {
                          selectedArtist = value as int;
                        });
                      },
                    ),
                  );
                }),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: assigning ? null : _assignArtist,

                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                  ),

                  child: assigning
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Assign Artist"),
                ),
              ],
            ),
    );
  }
}
