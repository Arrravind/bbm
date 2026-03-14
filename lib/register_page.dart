import 'dart:convert';
import 'meta_events.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';
import 'utils/network_utils.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _passwordController = TextEditingController();
  final _businessController = TextEditingController();
  final _contactController = TextEditingController();
  final _instagramController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _couponController = TextEditingController();

  // Category
  String? _selectedCategory;
  final List<String> _categories = [
    'Makeup',
    'Photography',
    'Events (Dance, Catering etc.)',
    'Others',
  ];

  // Error messages
  String? whatsappError;
  String? passwordError;
  String? businessError;
  String? contactError;
  String? instagramError;
  String errorMessage = "";

  bool _obscurePassword = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    // Dynamic WhatsApp validation
    _whatsappController.addListener(() {
      final text = _whatsappController.text.trim();
      final whatsappRegex = RegExp(r'^[0-9]{10}$');

      setState(() {
        if (text.isEmpty) {
          whatsappError = "Enter WhatsApp number";
        } else if (!whatsappRegex.hasMatch(text)) {
          whatsappError = "WhatsApp number must be exactly 10 digits";
        } else {
          whatsappError = null;
        }
      });
    });

    // Dynamic Password validation
    _passwordController.addListener(() {
      final text = _passwordController.text.trim();
      final passwordRegex = RegExp(r'^(?=.*[0-9])(?=.*[\W_]).{8,50}$');

      setState(() {
        if (text.isEmpty) {
          passwordError = "Enter password";
        } else if (!passwordRegex.hasMatch(text)) {
          passwordError =
              "Password must be 8–50 chars, include number & special char";
        } else {
          passwordError = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _businessController.dispose();
    _contactController.dispose();
    _instagramController.dispose();
    _whatsappController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.pinkAccent),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
      ),
    );
  }

  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate()) {
      final whatsapp = _whatsappController.text.trim();
      final password = _passwordController.text.trim();
      final business = _businessController.text.trim();
      final contact = _contactController.text.trim();
      final instagram = _instagramController.text.trim();
      final category = _selectedCategory ?? "";
      final coupon = _couponController.text.trim();

      // Password validation (frontend)
      final passwordRegex = RegExp(r'^(?=.*[0-9])(?=.*[\W_]).{8,50}$');
      if (!passwordRegex.hasMatch(password)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Password must be 8–50 characters, include a number and a special character.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      setState(() {
        isLoading = true;
      });

      try {
        await NetworkUtils.checkConnectivity();
        var url = Uri.parse(ApiConfig.registerEndpoint);
        var response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "whatsapp": whatsapp,
            "password": password,
            "business_name": business,
            "contact_person": contact,
            "instagram": instagram,
            "category": category,
            "coupon_code": coupon.isNotEmpty ? coupon : null,
          }),
        );

        debugPrint(response.body);
        debugPrint("status code: ${response.statusCode} | from register page");
        if (response.statusCode == 200 || response.statusCode == 201) {
          var data = jsonDecode(response.body);
          if (data['success'] == true) {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString("auth_token", data["token"]);
            await prefs.setInt("user_id", data["user"]["id"]);
            await prefs.setInt("level", data["user"]["level"]);
            await prefs.setString("username", data["user"]["username"]);
            await prefs.setString("role", data["user"]["role"]);
            await prefs.setString(
              "business_name",
              data["user"]["business_name"] ?? "",
            );

            debugPrint("META DEBUG: CompleteRegistration about to fire");
            facebookAppEvents.logEvent(name: 'CompleteRegistration');
            debugPrint("META DEBUG: CompleteRegistration fired");
            if (mounted) {
              Navigator.pushReplacementNamed(context, "/Subscription");
            }
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("An error occurred: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Text(
                  "Bridal Booker Machine",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink.shade800,
                  ),
                ),
                const SizedBox(height: 30),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // WhatsApp
                      TextFormField(
                        controller: _whatsappController,
                        decoration: _inputDecoration(
                          "WhatsApp Number",
                          FontAwesomeIcons.whatsapp,
                        ).copyWith(errorText: whatsappError),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 15),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration("Password", Icons.lock)
                            .copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              errorText: passwordError,
                            ),
                      ),
                      const SizedBox(height: 15),

                      // Business Name
                      TextFormField(
                        controller: _businessController,
                        decoration: _inputDecoration(
                          "Business Name",
                          Icons.store,
                        ).copyWith(errorText: businessError),
                        validator: (value) =>
                            value!.isEmpty ? "Enter business name" : null,
                      ),
                      const SizedBox(height: 15),

                      // Contact Person
                      TextFormField(
                        controller: _contactController,
                        decoration: _inputDecoration(
                          "Contact Person",
                          Icons.person_pin,
                        ).copyWith(errorText: contactError),
                        validator: (value) =>
                            value!.isEmpty ? "Enter contact person" : null,
                      ),
                      const SizedBox(height: 15),

                      // Instagram
                      TextFormField(
                        controller: _instagramController,
                        decoration: _inputDecoration(
                          "Instagram Handle",
                          Icons.camera_alt,
                        ).copyWith(errorText: instagramError),
                        validator: (value) =>
                            value!.isEmpty ? "Enter Instagram handle" : null,
                      ),
                      const SizedBox(height: 15),

                      // Category (Dropdown)
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: _inputDecoration(
                          "Service Category",
                          Icons.category,
                        ),
                        items: _categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        },
                        validator: (value) => value == null || value.isEmpty
                            ? "Select category"
                            : null,
                      ),
                      const SizedBox(height: 15),

                      // Coupon Code (optional)
                      TextFormField(
                        controller: _couponController,
                        decoration: _inputDecoration(
                          "Coupon Code (optional)",
                          Icons.local_offer,
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: _registerUser,
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Register",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Already have account
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, "/login");
                        },
                        child: const Text(
                          "Already have an account? Login",
                          style: TextStyle(color: Colors.pink),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
