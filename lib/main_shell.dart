import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_page.dart';
import 'available_leads_page.dart';
import 'my_claims_page.dart';
import 'resources_page.dart';
import 'settings_page.dart';
import 'telecaller_dashboard_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  int availableCount = 0;
  int myClaimsCount = 0;
  bool isTelecaller = false;
  bool roleLoaded = false;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadRole();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString("role");

    if (!mounted) return;

    setState(() {
      isTelecaller = role == "telecaller";
      roleLoaded = true;
    });
  }

  // Called from DashboardPage
  void switchToTab(int index) {
    if (!mounted) return;

    setState(() {
      _currentIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String _getTitle() {
    if (isTelecaller) {
      switch (_currentIndex) {
        case 0:
          return "Telecaller Dashboard";
        case 1:
          return "Leads ($availableCount)";
        case 2:
          return "Resources";
        case 3:
          return "Settings";
        default:
          return "";
      }
    }

    switch (_currentIndex) {
      case 0:
        return "BBM Dashboard";
      case 1:
        return "Available Leads ($availableCount)";
      case 2:
        return "My Claims ($myClaimsCount)";
      case 3:
        return "Resources";
      case 4:
        return "Settings";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!roleLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      // ---------------- APP BAR ----------------
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          _getTitle(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // ---------------- BODY ----------------
      body: PageView(
        controller: _pageController,

        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        children: isTelecaller
            ? [
                /// TELECALLER PAGES
                const TelecallerDashboardPage(),

                AvailableLeadsPage(
                  isTelecaller: true,
                  onCountChanged: (count) {
                    if (count != availableCount) {
                      setState(() {
                        availableCount = count;
                      });
                    }
                  },
                ),

                const ResourcesPage(),

                const SettingsPage(),
              ]
            : [
                // DASHBOARD
                DashboardPage(onNavigate: switchToTab),

                // AVAILABLE LEADS
                AvailableLeadsPage(
                  onCountChanged: (count) {
                    if (count != availableCount) {
                      setState(() {
                        availableCount = count;
                      });
                    }
                  },
                ),

                // MY CLAIMS
                MyClaimsPage(
                  onCountChanged: (count) {
                    if (count != myClaimsCount) {
                      setState(() {
                        myClaimsCount = count;
                      });
                    }
                  },
                ),

                // RESOURCES
                const ResourcesPage(),

                // SETTINGS
                const SettingsPage(),
              ],
      ),

      // ---------------- BOTTOM NAV ----------------
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: (index) => switchToTab(index),
        items: isTelecaller
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.work_outline),
                  activeIcon: Icon(Icons.work),
                  label: 'Leads',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.play_circle_outline),
                  activeIcon: Icon(Icons.play_circle),
                  label: 'Resources',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.work_outline),
                  activeIcon: Icon(Icons.work),
                  label: 'Leads',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_outlined),
                  activeIcon: Icon(Icons.assignment),
                  label: 'My Claims',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.play_circle_outline),
                  activeIcon: Icon(Icons.play_circle),
                  label: 'Resources',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
      ),
    );
  }
}
