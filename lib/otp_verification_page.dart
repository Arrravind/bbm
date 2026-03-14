import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'reset_password_page.dart';
import 'dart:async';

class OTPVerificationPage extends StatefulWidget {
  final String phoneNumber;

  const OTPVerificationPage({super.key, required this.phoneNumber});

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController otpController = TextEditingController();

  int secondsRemaining = 60;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() {
          secondsRemaining--;
        });
      }
    });
  }

  void verifyOTP() {
    if (otpController.text.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter valid OTP")));
      return;
    }

    // Backend verification will be added later

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordPage(phoneNumber: widget.phoneNumber),
      ),
    );
  }

  void resendOTP() {
    setState(() {
      secondsRemaining = 60;
    });

    startTimer();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("OTP resent")));

    // Backend resend API will be added later
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OTP Verification"), centerTitle: true),

      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE3F2FD), Color(0xFF64B5F6), Color(0xFF1E88E5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),

          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),

                child: Card(
                  elevation: 12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Padding(
                    padding: const EdgeInsets.all(25),

                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// OTP Icon
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(
                            Icons.lock_outline,
                            size: 30,
                            color: Colors.blue,
                          ),
                        ),

                        const SizedBox(height: 15),

                        Text(
                          "Verify OTP",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          "Enter the verification code sent to",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          widget.phoneNumber,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 10),

                        /// WhatsApp Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.message,
                              color: Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Code sent via WhatsApp",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        /// OTP Input
                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            letterSpacing: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: "------",
                            counterText: "",
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// Verify Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: verifyOTP,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Verify OTP",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// Timer / Resend
                        if (secondsRemaining > 0)
                          Text(
                            "Resend OTP in $secondsRemaining seconds",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),

                        if (secondsRemaining == 0)
                          SizedBox(
                            width: double.infinity,

                            child: ElevatedButton(
                              onPressed: resendOTP,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),

                              child: Text(
                                "Resend OTP",
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
