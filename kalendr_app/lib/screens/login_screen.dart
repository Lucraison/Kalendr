import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../l10n/app_strings.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegister = false;
  bool _busy = false;
  String _error = '';

  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  Future<void> _submit() async {
    setState(() { _busy = true; _error = ''; });
    try {
      final provider = context.read<AppProvider>();
      if (_isRegister) {
        await provider.register(_username.text.trim(), _email.text.trim(), _password.text);
      } else {
        await provider.login(_username.text.trim(), _password.text);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _langBtn(String code, String label, AppProvider provider) {
    final active = provider.locale == code;
    return TextButton(
      onPressed: () => provider.setLocale(code),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? kPrimary : KalendrTheme.muted(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final s = context.s;
    return Scaffold(
      backgroundColor: KalendrTheme.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 52),

              // Logo
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Center(child: Text('📅', style: TextStyle(fontSize: 38))),
              ),
              const SizedBox(height: 14),

              Text('Kalendr', style: GoogleFonts.nunito(fontSize: 36, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
              const SizedBox(height: 4),
              Text(s.loginSubtitle, style: GoogleFonts.nunito(fontSize: 14, color: KalendrTheme.subtext(context))),
              const SizedBox(height: 14),

              // Language selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _langBtn('en', 'EN', provider),
                  Text('|', style: TextStyle(color: Colors.grey.shade300)),
                  _langBtn('fr', 'FR', provider),
                  Text('|', style: TextStyle(color: Colors.grey.shade300)),
                  _langBtn('es', 'ES', provider),
                ],
              ),
              const SizedBox(height: 28),

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
                child: Column(
                  children: [
                    _field(_username, s.username, Icons.person_outline),
                    if (_isRegister) ...[
                      const SizedBox(height: 12),
                      _field(_email, s.email, Icons.email_outlined, keyboard: TextInputType.emailAddress),
                    ],
                    const SizedBox(height: 12),
                    _field(_password, s.password, Icons.lock_outline, obscure: true),
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
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(_isRegister ? s.register : s.login,
                              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => setState(() { _isRegister = !_isRegister; _error = ''; }),
                child: Text(
                  _isRegister ? s.toggleLogin : s.toggleRegister,
                  style: GoogleFonts.nunito(color: kPrimary, fontSize: 14),
                ),
              ),
              if (!_isRegister)
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: Text(s.forgotPassword, style: GoogleFonts.nunito(color: KalendrTheme.subtext(context), fontSize: 13)),
                ),
              const SizedBox(height: 32),
            ],
          ),
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
