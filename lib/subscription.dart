import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'config/api_config.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'meta_events.dart';
import 'main_shell.dart';

class Level5SubscriptionPage extends StatefulWidget {
  const Level5SubscriptionPage({super.key});

  @override
  State<Level5SubscriptionPage> createState() => _Level5SubscriptionPageState();
}

class _Level5SubscriptionPageState extends State<Level5SubscriptionPage> {
  late Razorpay _razorpay;

  String? _razorpayOrderId;
  int? selectedPlanId;
  int? payableAmount;
  String? currency;

  List<dynamic> subscriptionPlans = [];
  Map<String, dynamic>? basicPlan;
  Map<String, dynamic>? trialPlan;
  Map<String, dynamic>? extendedPlan;
  Map<String, dynamic>? elitePlan;

  bool _isPaying = false;
  Timer? _paymentTimeout;
  bool _eliteExpanded = false;
  bool _playVideoInline = false;

  String? _wistiaId;
  bool _videoLoading = true;
  bool _videoError = false;

  Map<String, dynamic> uiConfig = {};
  bool uiLoaded = false;

  List<String> getPlanPoints(String planKey) {
    List<String> points = [];

    int i = 1;

    while (true) {
      String key = "${planKey}_point_$i";

      if (uiConfig.containsKey(key)) {
        points.add(uiConfig[key]);
        i++;
      } else {
        break;
      }
    }

    return points;
  }

  Future<void> fetchUIConfig() async {
    try {
      debugPrint("FETCH UI CONFIG CALLED");

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      debugPrint("TOKEN => $token");

      final url =
          "${ApiConfig.uiConfigEndpoint}?screen=subscription&token=$token";

      debugPrint("URL => $url");

      final res = await http.get(Uri.parse(url));

      debugPrint("STATUS => ${res.statusCode}");

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

  Future<void> _fetchSubscriptionVideo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      final response = await http.post(
        Uri.parse(ApiConfig.subscriptionIntroVideoEndpoint),
        headers: {"Content-Type": "applicatio_videoControllern/json"},
        body: jsonEncode({"token": token}),
      );

      final data = jsonDecode(response.body);
      final wistiaId = data["video"]["wistia_id"];

      if (!mounted) return;

      setState(() {
        _wistiaId = wistiaId;
        _videoLoading = false;
      });
    } catch (e) {
      setState(() {
        _videoError = true;
        _videoLoading = false;
      });
    }
  }

  Future<void> fetchSubscriptionPlans() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getSubscriptionPlansEndpoint),
      );

      final data = jsonDecode(response.body);

      if (data["plans"] != null && data["plans"] is List) {
        setState(() {
          for (var plan in data["plans"]) {
            if (plan["slug"] == "basic") {
              basicPlan = plan;
            } else if (plan["slug"] == "extended_basic") {
              extendedPlan = plan;
            } else if (plan["slug"] == "elite") {
              elitePlan = plan;
            } else if (plan["slug"] == "trial") {
              trialPlan = plan;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("fetchSubscriptionPlans error: $e");
    }
  }

  @override
  void initState() {
    super.initState();

    fetchSubscriptionPlans();
    _fetchSubscriptionVideo();

    fetchUIConfig();
    // _fireRegistrationEventIfNeeded();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> createRazorpayOrder(Map<String, dynamic> plan) async {
    if (_isPaying) return;
    _isPaying = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("user_id");

      selectedPlanId = plan["id"];

      final response = await http.post(
        Uri.parse(ApiConfig.createRazorpayOrderEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "plan_id": selectedPlanId}),
      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        _razorpayOrderId = data["order_id"];
        payableAmount = data["amount"];
        currency = data["currency"];

        openRazorpayCheckout();
      }
    } finally {
      _isPaying = false;
    }
  }

  void openRazorpayCheckout() {
    var options = {
      'key': 'rzp_live_S2XFFjRvkMZHEM',
      'order_id': _razorpayOrderId,
      'amount': 100,
      'currency': currency,
      'name': 'Loki Web Vibe',
      'theme': {'color': '#3399cc'},
    };

    _paymentTimeout = Timer(const Duration(minutes: 5), () {
      _showDialog(
        title: "Payment Pending",
        message:
            "If amount was deducted, your plan will be activated automatically. Otherwise, please try again.",
      );
    });

    _razorpay.open(options);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Payment Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    _paymentTimeout?.cancel();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("user_id");

      if (userId == null) {
        debugPrint("ERROR: user_id is null");

        if (!mounted) return;
        _showErrorDialog("User not found. Please login again.");
        return;
      }

      if (selectedPlanId == null) {
        debugPrint("ERROR: selectedPlanId is null");

        if (!mounted) return;
        _showErrorDialog("Plan not selected properly.");
        return;
      }

      debugPrint("Sending Payment Verification...");
      debugPrint("UserID: $userId");
      debugPrint("PlanID: $selectedPlanId");
      debugPrint("PaymentID: ${response.paymentId}");
      debugPrint("OrderID: ${response.orderId}");

      final verifyResponse = await http.post(
        Uri.parse(ApiConfig.confirmRazorpayPaymentEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "plan_id": selectedPlanId,
          "razorpay_payment_id": response.paymentId,
          "razorpay_order_id": response.orderId,
          "razorpay_signature": response.signature,
        }),
      );

      debugPrint("HTTP Status: ${verifyResponse.statusCode}");
      debugPrint("Raw Response: ${verifyResponse.body}");

      Map<String, dynamic> result;

      try {
        result = jsonDecode(verifyResponse.body);
      } catch (e) {
        debugPrint("JSON PARSE ERROR: $e");

        if (!mounted) return;
        _showErrorDialog("Invalid server response");
        return;
      }

      if (!mounted) return;

      // ✅ SUCCESS CASE
      if (result["success"] == true) {
        debugPrint("Payment Verified Successfully");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );

        facebookAppEvents.logEvent(name: 'CompleteRegistration');
        return;
      }

      // ❌ FAILURE CASE (Handled cleanly)
      final errorCode = result["error_code"] ?? "UNKNOWN_ERROR";
      final message = result["message"] ?? "Something went wrong";

      debugPrint("Payment Failed");
      debugPrint("Error Code: $errorCode");
      debugPrint("Message: $message");

      _showErrorDialog(message);
    } catch (e, stackTrace) {
      debugPrint("EXCEPTION OCCURRED: $e");
      debugPrint("STACKTRACE: $stackTrace");

      if (!mounted) return;
      _showErrorDialog("Something went wrong. Please try again.");
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _paymentTimeout?.cancel();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Payment Failed"),
        content: Text("Payment could not be completed"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showDialog(
      title: "External Wallet Selected",
      message: response.walletName ?? "",
    );
  }

  void _showDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // Future<void> _fireRegistrationEventIfNeeded() async {
  //   final prefs = await SharedPreferences.getInstance();

  //   // Get logged-in user ID
  //   final int? userId = prefs.getInt("user_id");

  //   if (userId == null) {
  //     // Safety check: user not logged in
  //     return;
  //   }

  //   // Create user-specific key
  //   final String eventKey = "registration_event_sent_$userId";

  //   final bool alreadySent = prefs.getBool(eventKey) ?? false;

  //   if (!alreadySent) {
  //     debugPrint("META DEBUG: Firing CompleteRegistration for user $userId");

  //     facebookAppEvents.logEvent(name: 'CompleteRegistration');

  //     debugPrint("META DEBUG: Firied CompleteRegistration for user $userId");

  //     // Mark event as sent
  //     await prefs.setBool(eventKey, true);
  //   } else {
  //     debugPrint(
  //       "META DEBUG: Registration event already sent for user $userId",
  //     );
  //   }
  // }

  // temp whatsapp plan message opener
  Future<void> openWhatsAppPlan(String planKey) async {
    String phone = getWhatsappPhone(planKey);
    String message = getWhatsappMessage(planKey);

    final encodedMessage = Uri.encodeComponent(message);

    final Uri whatsappUrl = Uri.parse(
      "https://wa.me/$phone?text=$encodedMessage",
    );
    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Failed to open WhatsApp: $e");
      throw Exception("Could not launch WhatsApp. Please try again.");
    }
  }

  // Call backend to create order and return payment URL
  // Future<String?> createPaymentOrder(String planName, int amount) async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final userId = prefs.getInt("user_id")?.toString() ?? '';

  //     final Uri url = Uri.parse(ApiConfig.createOrderEndpoint);

  //     final response = await http.post(
  //       url,
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({
  //         'planName': planName,
  //         'amount': amount,
  //         'userId': userId,
  //       }),
  //     );

  //     debugPrint('Create Order Response: ${response.body}');
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       return data['paymentUrl'];
  //     } else {
  //       debugPrint('Failed to create order: ${response.body}');
  //       return null;
  //     }
  //   } catch (e) {
  //     debugPrint('Error creating order: $e');
  //     return null;
  //   }
  // }

  // Open PhonePe payment in external browser
  // Future<void> openPayment(String paymentUrl) async {
  //   try {
  //     await launchUrl(
  //       Uri.parse(paymentUrl),
  //       mode: LaunchMode.externalApplication,
  //     );
  //   } catch (e) {
  //     debugPrint('Error launching payment URL: $e');
  //   }
  // }

  String getWhatsappPhone(String planKey) {
    return uiConfig["${planKey}_whatsapp_phone"] ?? "";
  }

  String getWhatsappMessage(String planKey) {
    return uiConfig["${planKey}_whatsapp_message"] ?? "";
  }

  Widget _inlineWistiaPlayer() {
    if (_wistiaId == null) return const SizedBox.shrink();

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadHtmlString(_buildWistiaHtml(_wistiaId!));

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: WebViewWidget(controller: controller),
      ),
    );
  }

  Widget _inlineVideoCard() {
    if (_videoLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_videoError || _wistiaId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          "Video unavailable",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,

            child: Stack(
              children: [
                _inlineWistiaPlayer(),

                // Play overlay ONLY before tap
                if (!_playVideoInline)
                  Positioned.fill(
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _playVideoInline = true;
                          });
                        },
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 70,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _commonActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: outlined ? Colors.white : Colors.purpleAccent,
          borderRadius: BorderRadius.circular(18),
          border: outlined
              ? Border.all(color: Colors.purpleAccent, width: 2)
              : null,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: outlined ? Colors.purpleAccent : Colors.white,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: outlined ? Colors.purpleAccent : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: outlined ? Colors.black54 : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: outlined ? Colors.purpleAccent : Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  // Process payment using backend order and webhook
  Widget _buildStatCard(String value, String label) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _eliteFeatureSection({
    required IconData icon,
    required String title,
    required List<String> points,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.pinkAccent, size: 20),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...points.map(
          (p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String title,
    Widget? priceWidget,
    required String duration,
    required List<String> points,
    required String buttonText,
    bool popular = false,
    bool isElite = false,
    VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (popular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.yellow[700],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Most Popular",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(height: 10),

          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.purpleAccent,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          if (isElite) ...[
            const Text(
              "₹24,999",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.purpleAccent,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "per month",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.flash_on, color: Colors.orange, size: 18),
                SizedBox(width: 6),
                Text(
                  "Minimum 3-month commitment required",
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ---------- EXPAND / COLLAPSE BUTTON ----------
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _eliteExpanded = !_eliteExpanded;
                });
              },
              icon: Icon(
                _eliteExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              label: Text(
                _eliteExpanded ? "Hide plan details" : "View plan details",
              ),
            ),

            // ---------- ANIMATED CONTENT ----------
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _eliteExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isMobile = constraints.maxWidth < 600;

                    return isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _eliteFeatureSection(
                                icon: Icons.campaign,
                                title: "Campaign Management",
                                points: [
                                  "Complete 14-step system",
                                  "High-converting ad creatives",
                                  "Branding and content strategy",
                                  "Business portfolio setup",
                                  "Competitor analysis",
                                  "Meta ad campaign setup",
                                  "Targeted local campaigns",
                                ],
                              ),
                              const Divider(height: 30),
                              _eliteFeatureSection(
                                icon: Icons.rocket_launch,
                                title: "Advanced Features",
                                points: [
                                  "Advanced lead filtering",
                                  "Automated follow-up system",
                                  "Full technical support",
                                  "Monthly optimization",
                                  "Unlimited campaigns",
                                  "Dedicated account manager",
                                  "Your ad budget included",
                                ],
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _eliteFeatureSection(
                                  icon: Icons.campaign,
                                  title: "Campaign Management",
                                  points: [
                                    "Complete 14-step system",
                                    "High-converting ad creatives",
                                    "Branding and content strategy",
                                    "Business portfolio setup",
                                    "Competitor analysis",
                                    "Meta ad campaign setup",
                                    "Targeted local campaigns",
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _eliteFeatureSection(
                                  icon: Icons.rocket_launch,
                                  title: "Advanced Features",
                                  points: [
                                    "Advanced lead filtering",
                                    "Automated follow-up system",
                                    "Full technical support",
                                    "Monthly optimization",
                                    "Unlimited campaigns",
                                    "Dedicated account manager",
                                    "Your ad budget included",
                                  ],
                                ),
                              ),
                            ],
                          );
                  },
                ),
              ),
            ),
          ]
          // ================= BASIC & EXTENDED =================
          else ...[
            // Text(
            //   price,
            //   style: const TextStyle(
            //     fontSize: 24,
            //     fontWeight: FontWeight.bold,
            //     color: Colors.purpleAccent,
            //   ),
            // ),
            priceWidget ?? const SizedBox(),
            const SizedBox(height: 5),
            Text(
              duration,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: points
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.pinkAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(p)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget priceWithOffer(String planKey) {
    bool hasOffer = (uiConfig["${planKey}_offer_enabled"] ?? "false") == "true";

    String original = uiConfig["${planKey}_original_price"] ?? "";

    String offer = uiConfig["${planKey}_offer_price"] ?? "";

    return Column(
      children: [
        if (hasOffer)
          Text(
            "₹$original",
            style: const TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
              fontSize: 18,
            ),
          ),

        Text(
          "₹${hasOffer ? offer : original}",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.purpleAccent,
          ),
        ),
      ],
    );
  }

  Future<void> _onRefresh() async {
    await fetchUIConfig();
    await fetchSubscriptionPlans();
  }

  @override
  Widget build(BuildContext context) {
    if (!uiLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 239, 167, 191),
        title: Text(
          uiConfig["appbar_title"] ?? "",
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          softWrap: true,
          overflow: TextOverflow.visible,
          maxLines: 2,
        ),

        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 239, 167, 191),
          ),
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildStatCard(
                          uiConfig["stat_1_value"] ?? "",
                          uiConfig["stat_1_label"] ?? "",
                        ),

                        _buildStatCard(
                          uiConfig["stat_2_value"] ?? "",
                          uiConfig["stat_2_label"] ?? "",
                        ),

                        _buildStatCard(
                          uiConfig["stat_3_value"] ?? "",
                          uiConfig["stat_3_label"] ?? "",
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/leads');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "${uiConfig["cta_title"]}\n",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.purpleAccent,
                              ),
                            ),

                            TextSpan(
                              text: uiConfig["cta_subtitle"] ?? "",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.purpleAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // _commonActionCard(
                    //   icon: Icons.play_circle_fill,
                    //   title: "Watch Video Tutorial",
                    //   subtitle: "See how leads, campaigns & bookings work",
                    //   onTap: () async {
                    //     const videoUrl = "https://your-video-link.com";
                    //     await launchUrl(
                    //       Uri.parse(videoUrl),
                    //       mode: LaunchMode.externalApplication,
                    //     );
                    //   },
                    // ),
                    _inlineVideoCard(),

                    const SizedBox(height: 14),

                    _commonActionCard(
                      icon: Icons.language,
                      title: "Visit Website for More Info",
                      subtitle: "Plans, FAQs, case studies & support",
                      outlined: true,
                      onTap: () async {
                        const websiteUrl = "https://bbm.lokiwebvibe.com/bbm/";
                        await launchUrl(
                          Uri.parse(websiteUrl),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),

                    const SizedBox(height: 14),
                    _buildPlanCard(
                      title: uiConfig["trial_title"] ?? "",
                      priceWidget: priceWithOffer("trial"),
                      duration: uiConfig["trial_duration"] ?? "",
                      points: getPlanPoints("trial"),
                      buttonText: "Start Trial Plan",
                      onTap: () {
                        if (trialPlan == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Loading plans, please wait..."),
                            ),
                          );
                          return;
                        }
                        createRazorpayOrder(trialPlan!);
                      },
                    ),
                    _buildPlanCard(
                      title: uiConfig["basic_title"] ?? "",
                      priceWidget: priceWithOffer("basic"),
                      duration: uiConfig["basic_duration"] ?? "",
                      points: getPlanPoints("basic"),
                      buttonText: "Start Basic Plan",
                      onTap: () {
                        if (basicPlan == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Loading plans, please wait..."),
                            ),
                          );
                          return;
                        }
                        createRazorpayOrder(basicPlan!);
                      },
                    ),
                    _buildPlanCard(
                      title: uiConfig["extended_title"] ?? "",
                      priceWidget: priceWithOffer("extended"),
                      duration:
                          "${uiConfig["extended_duration"]}\n${uiConfig["extended_save_text"]}",
                      points: getPlanPoints("extended"),
                      buttonText: "Choose Extended Plan",
                      popular: true,
                      onTap: () {
                        if (extendedPlan == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Loading plans, please wait..."),
                            ),
                          );
                          return;
                        }
                        createRazorpayOrder(extendedPlan!);
                      },
                    ),
                    // _buildPlanCard(
                    //   title: "Elite Plan",
                    //   price: "",
                    //   duration: "",
                    //   points: const [],
                    //   buttonText: "Choose Elite Plan",
                    //   isElite: true,
                    //   onTap: () {
                    //     if (elitePlan == null) {
                    //       ScaffoldMessenger.of(context).showSnackBar(
                    //         const SnackBar(
                    //           content: Text("Loading plans, please wait..."),
                    //         ),
                    //       );
                    //       return;
                    //     }
                    //     createRazorpayOrder(elitePlan!);
                    //   },
                    // ),
                    // // _buildPlanCard(
                    //   title: "Elite Plan",
                    //   price: "Custom Pricing",
                    //   duration: "Contact us for details",
                    //   points: [
                    //     "Exclusive leads only for you",
                    //     "Priority support included",
                    //   ],
                    //   buttonText: "Know More",
                    //   isWhatsapp: true,
                    // ),
                    // const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _buildWistiaHtml(String id) {
  return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<script src="https://fast.wistia.com/assets/external/E-v1.js" async></script>
<style>
html, body {
  margin: 0;
  background: transparent;
}
.wistia_embed {
  width: 100%;
  height: 100%;
}
</style>
</head>
<body>

<div class="wistia_embed wistia_async_$id
  controlsVisibleOnLoad=true
  fullscreenButton=true
  videoFoam=true">
</div>

<script>
window._wq = window._wq || [];
_wq.push({
  id: "$id",
  onReady: function(video) {
    video.pause();
  }
});
</script>

</body>
</html>
''';
}
