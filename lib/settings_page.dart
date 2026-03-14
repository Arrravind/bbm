import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String username = '';
  String role = '';
  int userId = 0;
  int level = 0;
  String authToken = '';
  String businessName = '';
  String artistLevel = '';
  String location = '';
  String whatsappNumber = '';
  String instagramHandle = '';
  String facebookPage = '';
  String websiteUrl = '';
  String status = '';

  String? _usernameError;
  String? _whatsappError;
  String? _websiteError;
  String? _instagramError;
  String? _facebookError;
  String? _locationError;
  String? _businessError;

  bool isLoading = true;
  bool isIncomplete = false;
  bool _isLoggingOut = false;

  bool _isValidUsername(String v) => v.length >= 4;
  bool _isValidWhatsapp(String v) => RegExp(r'^[0-9]{10}$').hasMatch(v);
  bool _isValidUrl(String v) =>
      v.startsWith('http://') || v.startsWith('https://');

  final TextEditingController instagramController = TextEditingController();
  final TextEditingController facebookController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();

    websiteController.addListener(() {
      if (_websiteError != null) {
        setState(() => _websiteError = null);
      }
    });
  }

  bool get _showAppBar {
    return status.toLowerCase() == 'inactive' && level == 5;
  }

  Future<void> _loadProfile() async {
    if (_isLoggingOut) return;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      authToken = prefs.getString('auth_token') ?? '';
      userId = prefs.getInt('user_id') ?? 0;
      level = prefs.getInt('level') ?? 0;
      username = prefs.getString('username') ?? '';
      role = prefs.getString('role') ?? '';
      businessName = prefs.getString('business_name') ?? '';
    });

    final storedProfile = prefs.getString('artist_profile');
    if (storedProfile != null) {
      _setProfileData(jsonDecode(storedProfile));
    }

    try {
      if (authToken.isEmpty) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      final res = await http.get(
        Uri.parse("${ApiConfig.getArtistProfileEndpoint}?token=$authToken"),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['profile'] != null) {
          _setProfileData(data['profile']);
          await prefs.setString('artist_profile', jsonEncode(data['profile']));

          if (status == 'inactive' && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/Subscription');
            });
          }
        }
      }
    } catch (_) {}

    _checkIncompleteFields();
    setState(() => isLoading = false);
  }

  void _setProfileData(Map<String, dynamic> data) {
    setState(() {
      username = data['username'] ?? username;
      businessName = data['business_name'] ?? businessName;
      artistLevel = data['artist_level'] ?? 'N/A';
      location = data['location'] ?? '';
      whatsappNumber = data['whatsapp_number'] ?? '';
      instagramHandle = data['instagram_handle'] ?? '';
      facebookPage = data['facebook_page'] ?? '';
      websiteUrl = data['website_url'] ?? '';
      status = data['status'] ?? '';
    });
  }

  void _checkIncompleteFields() {
    isIncomplete =
        instagramHandle.isEmpty ||
        facebookPage.isEmpty ||
        websiteUrl.isEmpty ||
        location.isEmpty;
  }

  Future<void> _logout() async {
    _isLoggingOut = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  void _showProfileDialog({bool editAll = false}) {
    _usernameError = null;
    _whatsappError = null;
    _websiteError = null;
    _instagramError = null;
    _facebookError = null;
    _locationError = null;
    _businessError = null;

    instagramController.text = editAll ? instagramHandle : '';
    facebookController.text = editAll ? facebookPage : '';
    websiteController.text = editAll ? websiteUrl : '';
    locationController.text = editAll ? location : '';

    final businessController = TextEditingController(
      text: editAll ? businessName : '',
    );
    final whatsappController = TextEditingController(
      text: editAll ? whatsappNumber : '',
    );

    final usernameController = TextEditingController(
      text: editAll ? username : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            usernameController.addListener(() {
              if (_usernameError != null) {
                setSheetState(() => _usernameError = null);
              }
            });
            whatsappController.addListener(() {
              if (_whatsappError != null) {
                setSheetState(() => _whatsappError = null);
              }
            });
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      editAll ? "Edit Profile" : "Complete Profile",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (editAll && username.isNotEmpty)
                      _sheetField(
                        "Username",
                        usernameController,
                        errorText: _usernameError,
                      ),

                    if (editAll && businessName.isNotEmpty)
                      _sheetField(
                        "Business Name",
                        businessController,
                        errorText: _businessError,
                      ),

                    if (editAll && whatsappNumber.isNotEmpty)
                      _sheetField(
                        "WhatsApp Number",
                        whatsappController,
                        errorText: _whatsappError,
                      ),

                    // EDIT PROFILE → show only if already filled
                    if (editAll && instagramHandle.isNotEmpty)
                      _sheetField(
                        "Instagram Handle",
                        instagramController,
                        errorText: _instagramError,
                      ),

                    // COMPLETE PROFILE → show only if empty
                    if (!editAll && instagramHandle.isEmpty)
                      _sheetField(
                        "Instagram Handle",
                        instagramController,
                        errorText: _instagramError,
                      ),

                    if (editAll && facebookPage.isNotEmpty)
                      _sheetField(
                        "Facebook Page",
                        facebookController,
                        errorText: _facebookError,
                      ),

                    if (!editAll && facebookPage.isEmpty)
                      _sheetField(
                        "Facebook Page",
                        facebookController,
                        errorText: _facebookError,
                      ),

                    if (editAll && websiteUrl.isNotEmpty)
                      _sheetField(
                        "Website URL",
                        websiteController,
                        errorText: _websiteError,
                      ),

                    if (!editAll && websiteUrl.isEmpty)
                      _sheetField(
                        "Website URL",
                        websiteController,
                        errorText: _websiteError,
                      ),

                    if (editAll && location.isNotEmpty)
                      _sheetField(
                        "Location",
                        locationController,
                        errorText: _locationError,
                      ),

                    if (!editAll && location.isEmpty)
                      _sheetField(
                        "Location",
                        locationController,
                        errorText: _locationError,
                      ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final Map<String, String> body = {};

                            // reset errors
                            setSheetState(() {
                              _usernameError = null;
                              _businessError = null;
                              _whatsappError = null;
                              _instagramError = null;
                              _facebookError = null;
                              _websiteError = null;
                              _locationError = null;
                            });

                            bool hasError = false;

                            /* ================= EDIT PROFILE (STRICT) ================= */

                            if (editAll) {
                              // USERNAME
                              final v = usernameController.text.trim();
                              if (v.isEmpty) {
                                _usernameError = "Username cannot be empty";
                                hasError = true;
                              } else if (!_isValidUsername(v)) {
                                _usernameError =
                                    "Minimum 4 characters required";
                                hasError = true;
                              } else if (v != username) {
                                body['username'] = v;
                              }

                              // BUSINESS
                              final b = businessController.text.trim();
                              if (b.isEmpty) {
                                _businessError =
                                    "Business name cannot be empty";
                                hasError = true;
                              } else if (b != businessName) {
                                body['business_name'] = b;
                              }

                              // WHATSAPP
                              final w = whatsappController.text.trim();
                              if (w.isEmpty) {
                                _whatsappError = "WhatsApp number is required";
                                hasError = true;
                              } else if (!_isValidWhatsapp(w)) {
                                _whatsappError = "Enter valid 10-digit number";
                                hasError = true;
                              } else if (w != whatsappNumber) {
                                body['whatsapp_number'] = w;
                              }
                            }

                            /* ================= COMPLETE PROFILE (FLEXIBLE) ================= */

                            // ---------- INSTAGRAM ----------
                            final insta = instagramController.text.trim();

                            if (editAll && instagramHandle.isNotEmpty) {
                              // EDIT PROFILE → must not be empty
                              if (insta.isEmpty) {
                                _instagramError =
                                    "Instagram handle cannot be empty";
                                hasError = true;
                              } else if (insta != instagramHandle) {
                                body['instagram_handle'] = insta;
                              }
                            } else if (!editAll && insta.isNotEmpty) {
                              // COMPLETE PROFILE → optional
                              body['instagram_handle'] = insta;
                            }

                            final fb = facebookController.text.trim();

                            if (editAll && facebookPage.isNotEmpty) {
                              if (fb.isEmpty) {
                                _facebookError =
                                    "Facebook page cannot be empty";
                                hasError = true;
                              } else if (fb != facebookPage) {
                                body['facebook_page'] = fb;
                              }
                            } else if (!editAll && fb.isNotEmpty) {
                              body['facebook_page'] = fb;
                            }

                            // WEBSITE
                            final web = websiteController.text.trim();

                            if (editAll && websiteUrl.isNotEmpty) {
                              if (web.isEmpty) {
                                _websiteError = "Website URL is required";
                                hasError = true;
                              } else if (!_isValidUrl(web)) {
                                _websiteError = "Enter a valid website URL";
                                hasError = true;
                              } else if (web != websiteUrl) {
                                body['website_url'] = web;
                              }
                            } else if (!editAll && web.isNotEmpty) {
                              if (!_isValidUrl(web)) {
                                _websiteError = "Enter a valid website URL";
                                hasError = true;
                              } else {
                                body['website_url'] = web;
                              }
                            }

                            // LOCATION
                            final loc = locationController.text.trim();

                            if (editAll && location.isNotEmpty) {
                              if (loc.isEmpty) {
                                _locationError = "Location cannot be empty";
                                hasError = true;
                              } else if (loc != location) {
                                body['location'] = loc;
                              }
                            } else if (!editAll && loc.isNotEmpty) {
                              body['location'] = loc;
                            }

                            /* ================= VALIDATION RESULT ================= */

                            if (hasError) {
                              setSheetState(() {});
                              return;
                            }

                            // NO CHANGES
                            if (body.isEmpty) {
                              Navigator.pop(context);
                              await Future.delayed(
                                const Duration(milliseconds: 120),
                              );
                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("No changes applied"),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            /* ================= API CALL ================= */

                            final res = await http.post(
                              Uri.parse(
                                "${ApiConfig.updateArtistProfileEndpoint}?token=$authToken",
                              ),
                              body: body,
                            );

                            final data = jsonDecode(res.body);

                            // SUCCESS
                            if (data['success'] == true) {
                              _setProfileData(data['profile']);
                              _checkIncompleteFields();
                              if (!mounted) return;
                              Navigator.pop(context);
                              await Future.delayed(
                                const Duration(milliseconds: 120),
                              );
                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Profile updated successfully"),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            // USERNAME DUPLICATE
                            if (data['message'] == 'Username already taken') {
                              setSheetState(() {
                                _usernameError = "Username already taken";
                              });
                              return;
                            }
                          },
                          child: const Text(
                            "Save Changes",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Confirm Logout",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Are you sure you want to log out of your account?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Log Out",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
    if (shouldLogout == true) {
      if (!mounted) return;
      _logout();
    }
  }

  Widget _sheetField(
    String label,
    TextEditingController controller, {
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        cursorColor: Colors.deepPurple,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          filled: true,
          fillColor: Colors.grey.shade100,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _profileHeader() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: Colors.deepPurple,
          child: Icon(Icons.person, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              username,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              businessName,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _showAppBar
          ? AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.deepPurple,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              title: const Text(
                "Settings",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _profileHeader(),
                    const SizedBox(height: 20),

                    _settingsSection(
                      title: "Profile",
                      children: [
                        _infoTile("Username", username),
                        _divider(),
                        _infoTile("Business Name", businessName),
                        _divider(),
                        _infoTile("Artist Level", artistLevel),
                        _divider(),
                        _infoTile("Subscription Status", status),
                        _divider(),
                        _infoTile("Location", location),
                        _divider(),
                        _infoTile("WhatsApp", whatsappNumber),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _settingsSection(
                      title: "Account",
                      children: [
                        _settingsTile(
                          icon: Icons.edit,
                          label: "Edit Profile",
                          onTap: () => _showProfileDialog(editAll: true),
                        ),
                        if (isIncomplete) ...[
                          _divider(),
                          _settingsTile(
                            icon: Icons.info_outline,
                            label: "Complete Profile",
                            onTap: () => _showProfileDialog(editAll: false),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    _settingsSection(
                      title: "Session",
                      children: [
                        _settingsTile(
                          icon: Icons.logout,
                          label: "Log Out",
                          isDestructive: true,
                          onTap: () => _confirmLogout(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value.isNotEmpty ? value : "-",
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey.shade200);
  }

  Widget _settingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : Colors.black;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
          ],
        ),
      ),
    );
  }
}
