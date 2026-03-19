import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _Page(
      emoji: '🗓️',
      title: 'Welcome to Kalendr',
      subtitle: 'A shared calendar for the people that matter — family, friends, teammates.',
      color: kPrimary,
    ),
    _Page(
      emoji: '👥',
      title: 'Groups keep you in sync',
      subtitle: 'Create or join a group, share events, and always know what\'s coming up.',
      color: Color(0xFF4ECDC4),
    ),
    _Page(
      emoji: '🎉',
      title: 'React and RSVP',
      subtitle: 'Let people know you\'re going, react to events, and pick your personal color.',
      color: Color(0xFF8338EC),
    ),
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
    return Scaffold(
      backgroundColor: KalendrTheme.bg(context),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _PageView(page: _pages[i]),
            ),
          ),

          // Dots
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_pages.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? _pages[_page].color : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          })),

          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              if (_page < _pages.length - 1) ...[
                TextButton(
                  onPressed: _finish,
                  child: Text('Skip', style: GoogleFonts.nunito(fontSize: 15, color: KalendrTheme.muted(context))),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _controller.nextPage(
                      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_page].color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  child: Text('Next', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ] else ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pages[_page].color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text("Let's go!", style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
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
