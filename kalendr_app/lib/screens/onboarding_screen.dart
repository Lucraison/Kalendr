import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../l10n/app_strings.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  List<_Page> _buildPages(AppStrings s) => [
    _Page(emoji: '🗓️', title: s.welcomeToKalendr, subtitle: s.onboardingDesc1, color: kPrimary),
    _Page(emoji: '👥', title: s.groupsKeepYouInSync, subtitle: s.onboardingDesc2, color: const Color(0xFF4ECDC4)),
    _Page(emoji: '🎉', title: s.reactAndRsvp, subtitle: s.onboardingDesc3, color: const Color(0xFF8338EC)),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingDone', true);
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final pages = _buildPages(s);
    return Scaffold(
      backgroundColor: KalendrTheme.bg(context),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _PageView(page: pages[i]),
            ),
          ),

          // Dots
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(pages.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? pages[_page].color : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          })),

          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              if (_page < pages.length - 1) ...[
                TextButton(
                  onPressed: _finish,
                  child: Text(s.skip, style: GoogleFonts.nunito(fontSize: 15, color: KalendrTheme.muted(context))),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _controller.nextPage(
                      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pages[_page].color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  child: Text(s.next, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ] else ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pages[_page].color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(s.letsGo, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  final _Page page;
  const _PageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            color: page.color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(page.emoji, style: const TextStyle(fontSize: 56))),
        ),
        const SizedBox(height: 40),
        Text(page.title,
            style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A2E)),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text(page.subtitle,
            style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _Page {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  const _Page({required this.emoji, required this.title, required this.subtitle, required this.color});
}
