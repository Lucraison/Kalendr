import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: const KalendrApp(),
    ),
  );
}

class KalendrApp extends StatelessWidget {
  const KalendrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kalendr',
      debugShowCheckedModeBanner: false,
      theme: KalendrTheme.light(),
      darkTheme: KalendrTheme.dark(),
      themeMode: context.watch<AppProvider>().themeMode,
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _onboardingDone = prefs.getBool('onboardingDone') ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (!provider.initialized || _onboardingDone == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F3F0),
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }
    if (!provider.auth.isLoggedIn) return const LoginScreen();
    if (!_onboardingDone!) {
      return OnboardingScreen(onDone: () => setState(() => _onboardingDone = true));
    }
    return const _MainNav();
  }
}

class _MainNav extends StatefulWidget {
  const _MainNav();

  @override
  State<_MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<_MainNav> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<AppProvider>().unreadCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? Colors.grey.shade500 : Colors.grey.shade600;

    final screens = [
      const CalendarScreen(),
      const GroupsScreen(),
      const NotificationsScreen(),
      ProfileScreen(onNavigateToTab: (i) => setState(() => _index = i)),
    ];

    return Scaffold(
      backgroundColor: KalendrTheme.surface(context),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        indicatorColor: kPrimary.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, color: mutedColor),
            selectedIcon: const Icon(Icons.calendar_month_rounded, color: kPrimary),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined, color: mutedColor),
            selectedIcon: const Icon(Icons.group_rounded, color: kPrimary),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread', style: GoogleFonts.nunito(fontSize: 10, color: Colors.white)),
              backgroundColor: kPrimary,
              child: Icon(Icons.notifications_outlined, color: mutedColor),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread', style: GoogleFonts.nunito(fontSize: 10, color: Colors.white)),
              backgroundColor: kPrimary,
              child: const Icon(Icons.notifications_rounded, color: kPrimary),
            ),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: mutedColor),
            selectedIcon: const Icon(Icons.person_rounded, color: kPrimary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
