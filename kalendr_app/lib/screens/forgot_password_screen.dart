import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../l10n/app_strings.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = ApiService();

  // Step 1: username input
  // Step 2: code + new password
  int _step = 1;
  bool _busy = false;
  String _error = '';

  final _usernameOrEmail = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  String _maskedEmail = '';

  @override
  void dispose() {
    _usernameOrEmail.dispose();
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final s = context.s;
    final input = _usernameOrEmail.text.trim();
    if (input.isEmpty) { setState(() => _error = s.enterYourUsername); return; }
    setState(() { _busy = true; _error = ''; });
    try {
      final masked = await _api.forgotPassword(input);
      if (mounted) setState(() { _maskedEmail = masked; _step = 2; _busy = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _busy = false; });
    }
  }

  Future<void> _resetPassword() async {
    final s = context.s;
    final code = _code.text.trim();
    final newPass = _newPassword.text;
    final confirm = _confirmPassword.text;
    if (code.isEmpty) { setState(() => _error = s.enterCodeFromEmail); return; }
    if (newPass.length < 6) { setState(() => _error = s.passwordAtLeast6); return; }
    if (newPass != confirm) { setState(() => _error = s.passwordsDoNotMatch); return; }
    setState(() { _busy = true; _error = ''; });
    try {
      await _api.resetPassword(_usernameOrEmail.text.trim(), code, newPass);
      if (!mounted) return;
      showSnack(context, context.s.passwordResetLoginAgain, color: const Color(0xFF06D6A0));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      backgroundColor: KalendrTheme.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const SizedBox(height: 52),

            // Icon
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_reset_rounded, color: kPrimary, size: 36),
            ),
            const SizedBox(height: 16),

            Text(
              _step == 1 ? s.forgotPassword : s.checkYourEmail,
              style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: KalendrTheme.text(context)),
            ),
            const SizedBox(height: 6),
            Text(
              _step == 1 ? s.enterUsernameOrEmailForCode : (_maskedEmail.isNotEmpty ? s.sentCodeTo(_maskedEmail) : s.checkYourEmail),
              style: GoogleFonts.nunito(fontSize: 14, color: KalendrTheme.subtext(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Card
            Container(
              decoration: BoxDecoration(
                color: KalendrTheme.surface(context),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                )],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                if (_step == 1) ...[
                  _field(_usernameOrEmail, s.usernameOrEmail, Icons.person_outline),
                ] else ...[
                  _field(_code, s.sixDigitCode, Icons.pin_rounded, keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(_newPassword, s.newPassword, Icons.lock_outline, obscure: true),
                  const SizedBox(height: 12),
                  _field(_confirmPassword, s.confirmPassword, Icons.lock_outline, obscure: true),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_error, style: const TextStyle(color: kPrimary, fontSize: 13), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 20),
                if (_busy)
                  const CircularProgressIndicator(color: kPrimary)
                else
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _step == 1 ? _sendCode : _resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _step == 1 ? s.sendCode : s.resetPassword,
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 16),

            if (_step == 2)
              TextButton(
                onPressed: () => setState(() { _step = 1; _error = ''; _code.clear(); _usernameOrEmail.clear(); _maskedEmail = ''; }),
                child: Text(s.resendCode, style: GoogleFonts.nunito(color: kPrimary, fontSize: 14)),
              ),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.backToLogin, style: GoogleFonts.nunito(color: KalendrTheme.subtext(context), fontSize: 14)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false, TextInputType keyboard = TextInputType.text}) {
    if (!obscure) {
      return Container(
        decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          style: GoogleFonts.nunito(color: KalendrTheme.text(context)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context)),
            prefixIcon: Icon(icon, color: KalendrTheme.muted(context), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      );
    }
    return StatefulBuilder(builder: (ctx, set) {
      bool hidden = true;
      return StatefulBuilder(builder: (ctx2, set2) => Container(
        decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
        child: TextField(
          controller: ctrl,
          obscureText: hidden,
          keyboardType: keyboard,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          style: GoogleFonts.nunito(color: KalendrTheme.text(context)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context)),
            prefixIcon: Icon(icon, color: KalendrTheme.muted(context), size: 20),
            suffixIcon: IconButton(
              icon: Icon(hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18, color: KalendrTheme.muted(context)),
              onPressed: () => set2(() => hidden = !hidden),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ));
    });
  }
}
