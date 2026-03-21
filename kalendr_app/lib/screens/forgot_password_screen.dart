import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = ApiService();

  // Step 1: email input
  // Step 2: code + new password
  int _step = 1;
  bool _busy = false;
  String _error = '';

  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (email.isEmpty) { setState(() => _error = 'Enter your email.'); return; }
    setState(() { _busy = true; _error = ''; });
    try {
      await _api.forgotPassword(email);
      if (mounted) setState(() { _step = 2; _busy = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _busy = false; });
    }
  }

  Future<void> _resetPassword() async {
    final code = _code.text.trim();
    final newPass = _newPassword.text;
    final confirm = _confirmPassword.text;
    if (code.isEmpty) { setState(() => _error = 'Enter the code from your email.'); return; }
    if (newPass.length < 6) { setState(() => _error = 'Password must be at least 6 characters.'); return; }
    if (newPass != confirm) { setState(() => _error = 'Passwords do not match.'); return; }
    setState(() { _busy = true; _error = ''; });
    try {
      await _api.resetPassword(_email.text.trim(), code, newPass);
      if (!mounted) return;
      showSnack(context, 'Password reset! Please log in.', color: const Color(0xFF06D6A0));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _step == 1 ? 'Forgot password?' : 'Check your email',
              style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: KalendrTheme.text(context)),
            ),
            const SizedBox(height: 6),
            Text(
              _step == 1
                  ? 'Enter your email and we\'ll send a 6-digit code.'
                  : 'We sent a code to ${_email.text.trim()}. Enter it below.',
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
                  _field(_email, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                ] else ...[
                  _field(_code, '6-digit code', Icons.pin_rounded, keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(_newPassword, 'New password', Icons.lock_outline, obscure: true),
                  const SizedBox(height: 12),
                  _field(_confirmPassword, 'Confirm password', Icons.lock_outline, obscure: true),
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
                        _step == 1 ? 'Send code' : 'Reset password',
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 16),

            if (_step == 2)
              TextButton(
                onPressed: () => setState(() { _step = 1; _error = ''; _code.clear(); }),
                child: Text('Resend code', style: GoogleFonts.nunito(color: kPrimary, fontSize: 14)),
              ),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Back to login', style: GoogleFonts.nunito(color: KalendrTheme.subtext(context), fontSize: 14)),
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
