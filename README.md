# BBM App Summary

A Flutter app called “BBM” / “BBM Artist App” for managing lead generation and booking workflows for artists/vendors (e.g., makeup, photography, events). It connects to a backend at `bbm.lokiwebvibe.com` and drives a subscription-based lead system.

## Core User Flow
1. Splash checks login state, user status, and app updates.
2. If not logged in → Login/Register.
3. If user is inactive or level 5 → Subscription paywall.
4. Otherwise → Main dashboard shell.

## Main Features
- Dashboard shows lead stats and recent claimed leads.
- Leads system:
  - Available leads list (claimable).
  - My Claims list (claimed leads) with status updates.
  - Lead detail page with contact info + WhatsApp and status updates.
- Subscription:
  - Plans loaded from API.
  - Razorpay checkout and verification.
  - Wistia intro video embedded.
- Resources:
  - Tutorial videos embedded via Wistia.
  - Access control for locked videos.

## Integrations
- Firebase (Core + FCM) with local notifications.
- Razorpay payments.
- Wistia via WebView.
- Facebook App Events.
- In‑app updates (Play Store).
- SharedPreferences for auth/session and cached profile data.

## Routes / Navigation
Key routes: `/`, `/login`, `/register`, `/dashboard`, `/leads`, `/available_leads`, `/my_claims`, `/lead_detail`, `/settings`, `/Subscription`.
