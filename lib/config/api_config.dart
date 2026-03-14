// https://bbm.lokiwebvibe.com/mobile_api/subscriptions/razorpay_webhook.php

class ApiConfig {

  static const String baseUrl = "https://bbm.lokiwebvibe.com"; 

  static const String loginEndpoint = "$baseUrl/mobile_api/auth.php";
  static const String uiConfigEndpoint = "$baseUrl/mobile_api/get_ui_config.php";
  static const String getSubscriptionPlansEndpoint = "$baseUrl/mobile_api/subscriptions/get_subscription_plans.php";
  static const String confirmRazorpayPaymentEndpoint = "$baseUrl/mobile_api/subscriptions/confirm_razorpay_payment.php";
  static const String createRazorpayOrderEndpoint = "$baseUrl/mobile_api/subscriptions/create_order.php";
  static const String callbackEndpoint = "$baseUrl/mobile_api/payment_callback.php";
  static const String tutorialVideosEndpoint = "$baseUrl/mobile_api/tutorial_videos.php";
  static const String subscriptionIntroVideoEndpoint = "$baseUrl/mobile_api/subscription-intro-video.php";
  static const String registerEndpoint = "$baseUrl/mobile_api/register.php";
  static const String availableLeadsEndpoint = "$baseUrl/mobile_api/all_leads.php";
  static const String claimStatsEndpoint = "$baseUrl/mobile_api/stats.php";
  static const String claimLeadEndpoint = "$baseUrl/mobile_api/claim_leads.php";
  static const String releaseLeadEndpoint = "$baseUrl/mobile_api/release.php";
  static const String updateStatusEndpoint = "$baseUrl/mobile_api/update_status.php";
  static const String getArtistProfileEndpoint = "$baseUrl/mobile_api/get_profile.php";
  static const String updateArtistProfileEndpoint = "$baseUrl/mobile_api/update_artist_profile.php";  
  static const String leadDetailsEndpoint = "$baseUrl/mobile_api/lead_details.php";
  static const String saveFCMTokenEndpoint = "$baseUrl/mobile_api/save_fcm_token.php";
  static const String addNewNoteEndpoint = "$baseUrl/mobile_api/add_new_note.php";
  static const String getFollowupStatusEndpoint = "$baseUrl/mobile_api/get_followup_status.php";
  static const String versionCheckEndpoint = "$baseUrl/mobile_api/check_app_version.php";
  static const String telecallerDashboardEndpoint = "$baseUrl/mobile_api/telecaller_dashboard.php";
  static const String eliteArtistsEndpoint = "$baseUrl/mobile_api/elite_artists.php";
  static const String assignArtistEndpoint = "$baseUrl/mobile_api/assign_artist.php";
}
