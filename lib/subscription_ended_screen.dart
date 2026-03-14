import 'package:flutter/material.dart';
import 'package:bbm_app/widgets/app_error_view.dart';

class SubscriptionEndedScreen extends StatelessWidget {
  const SubscriptionEndedScreen({super.key});

  void _goToPlans(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, "/Subscription", (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goToPlans(context);
      },
      child: Scaffold(
        body: AppErrorView(
          icon: Icons.lock_outline,
          title: "Subscription Ended",
          message:
              "You have reached your maximum lead claim limit for this plan. Please upgrade or renew your subscription to continue claiming leads.",
          buttonText: "View Subscription Plans",
          onPressed: () => _goToPlans(context),
        ),
      ),
    );
  }
}
