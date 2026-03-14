import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'otp_verification_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;
  String? phoneError;
  bool otpCooldown = false;
  int cooldownSeconds = 60;
  Timer? cooldownTimer;

  @override
  void dispose() {
    cooldownTimer?.cancel();
    phoneController.dispose();
    super.dispose();
  }

  void sendOTP() {
    String phone = phoneController.text.trim();

    setState(() {
      phoneError = null;
    });

    if (phone.isEmpty) {
      setState(() {
        phoneError = "Mobile number is required";
      });
      return;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      setState(() {
        phoneError = "Enter a valid 10 digit mobile number";
      });
      return;
    }

    if (otpCooldown) return;

    setState(() {
      otpCooldown = true;
    });

    startCooldown();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OTPVerificationPage(phoneNumber: phone),
      ),
    );
  }

  void startCooldown() {
    cooldownSeconds = 60;

    cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (cooldownSeconds == 0) {
        timer.cancel();
        setState(() {
          otpCooldown = false;
        });
      } else {
        setState(() {
          cooldownSeconds--;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),

      appBar: AppBar(title: const Text("Forgot Password"), centerTitle: true),

      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFE3F2FD), // very light blue (top near AppBar)
                Color(0xFF64B5F6),
                Color(0xFF1E88E5), // deeper blue bottom
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),

                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Padding(
                    padding: const EdgeInsets.all(25),

                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// Security Icon
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(
                            FontAwesomeIcons.lock,
                            size: 28,
                            color: Colors.blue,
                          ),
                        ),

                        const SizedBox(height: 15),

                        Text(
                          "Recover Your Account",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          "Enter your registered mobile number. ",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// WhatsApp indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              FontAwesomeIcons.whatsapp,
                              color: Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "OTP will be sent through WhatsApp",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        /// Mobile Input
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,

                          decoration: InputDecoration(
                            labelText: "Mobile Number",
                            prefixIcon: const Icon(Icons.phone),
                            errorText: phoneError,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 25),

                        /// Send OTP Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (isLoading || otpCooldown)
                                ? null
                                : sendOTP,

                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),

                            child: otpCooldown
                                ? Text("Wait $cooldownSeconds seconds")
                                : Text(
                                    "Send OTP",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
