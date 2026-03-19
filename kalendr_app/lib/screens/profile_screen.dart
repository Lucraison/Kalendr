import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(int)? onNavigateToTab;
  const ProfileScreen({super.key, this.onNavigateToTab});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Group> _groups = [];
  int _totalEvents = 0;
  bool _loading = true;
  int _upcomingEvents = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: KalendrTheme.surface(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: kPrimary),
            title: Text('Choose from gallery', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: kPrimary),
            title: Text('Take a photo', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (picked == null || !mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/profile_pic.jpg';
    await File(picked.path).copy(dest);
    final provider = context.read<AppProvider>();
    await provider.auth.saveProfilePic(dest);
    provider.refresh();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppProvider>().api;
      final groups = await api.getGroups();
      final eventLists = await Future.wait(groups.map((g) => api.getEvents(g.id)));
      final now = DateTime.now();
      int eventCount = 0;
      int upcomingCount = 0;
      for (final events in eventLists) {
        eventCount += events.length;
        upcomingCount += events.where((e) => e.startTime.isAfter(now)).length;
      }
      if (mounted) setState(() { _groups = groups; _totalEvents = eventCount; _upcomingEvents = upcomingCount; });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editUsername(AppProvider provider) async {
    final ctrl = TextEditingController(text: provider.auth.username ?? '');
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit username', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            style: GoogleFonts.nunito(),
            decoration: InputDecoration(
              hintText: 'Username',
              hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(ctx)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: KalendrTheme.field(ctx),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: GoogleFonts.nunito(color: kPrimary, fontSize: 13)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.nunito())),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().length < 2) { setDialog(() => error = 'At least 2 characters'); return; }
              Navigator.pop(ctx, true);
            },
            child: Text('Save', style: GoogleFonts.nunito(color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      )),
    );
    if (confirmed != true || !mounted) return;
    final newName = ctrl.text.trim();
    if (newName == provider.auth.username) return;
    try {
      await provider.updateUsername(newName);
      if (mounted) showSnack(context, 'Username updated!', color: const Color(0xFF06D6A0));
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    }
  }

  Color _groupColor(Group g) => groupColorFor(g.id);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final auth = provider.auth;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: KalendrTheme.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          color: kPrimary,
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 28),

              // ── Avatar + name ──────────────────────────────────────────
              Center(child: Column(children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), shape: BoxShape.circle),
                      child: auth.profilePicPath != null
                          ? ClipOval(child: Image.file(File(auth.profilePicPath!), width: 96, height: 96, fit: BoxFit.cover))
                          : Center(child: Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                color: kPrimary,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                              ),
                              child: Center(child: Text(auth.initials, style: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white))),
                            )),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: KalendrTheme.bg(context), width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => _editUsername(provider),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(auth.username ?? '',
                        style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_rounded, size: 15, color: KalendrTheme.muted(context)),
                  ]),
                ),
                if (auth.email != null) ...[
                  const SizedBox(height: 3),
                  Text(auth.email!, style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.muted(context))),
                ],
              ])),
              const SizedBox(height: 28),

              // ── Stats ──────────────────────────────────────────────────
              if (_loading)
                Row(children: List.generate(3, (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: KalendrTheme.surface(context),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(children: [
                        Skeleton(width: 44, height: 44, radius: 14),
                        const SizedBox(height: 8),
                        Skeleton(width: 32, height: 20, radius: 6),
                        const SizedBox(height: 6),
                        Skeleton(width: 48, height: 11, radius: 5),
                      ]),
                    ),
                  ),
                )))
              else
                Row(children: [
                  Expanded(child: _statCard(Icons.group_rounded, '${_groups.length}', 'Groups', const Color(0xFF4ECDC4),
                      onTap: () => widget.onNavigateToTab?.call(1))),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard(Icons.calendar_month_rounded, '$_totalEvents', 'Events', kPrimary)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard(Icons.upcoming_rounded,
                      _upcomingEvents == 0 ? '0' : '$_upcomingEvents', 'Upcoming', const Color(0xFF8338EC),
                      dimmed: _upcomingEvents == 0)),
                ]),
              const SizedBox(height: 32),

              // ── Settings ───────────────────────────────────────────────
              _sectionLabel('Settings'),
              const SizedBox(height: 10),
              _settingsCard(isDark, context, provider),
              const SizedBox(height: 28),

              // ── Your groups ────────────────────────────────────────────
              if (!_loading && _groups.isNotEmpty) ...[
                Row(children: [
                  _sectionLabel('Your Groups'),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => widget.onNavigateToTab?.call(1),
                    child: Text('See all', style: GoogleFonts.nunito(
                        fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
                  ),
                ]),
                const SizedBox(height: 10),
                ..._groups.map((g) => _groupRow(g)),
                const SizedBox(height: 28),
              ],

              // ── Danger zone ────────────────────────────────────────────
              _sectionLabel('Account'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(isDark ? 0.15 : 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade300.withOpacity(0.25)),
                ),
                child: ListTile(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text('Delete account?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                        content: Text(
                          'This permanently deletes your account, all your events, and removes you from all groups. This cannot be undone.',
                          style: GoogleFonts.nunito(),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.nunito())),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Delete', style: GoogleFonts.nunito(color: Colors.red.shade700, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true || !context.mounted) return;
                    try {
                      await provider.api.deleteAccount();
                      await provider.logout();
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                      );
                    }
                  },
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.delete_forever_rounded, color: Colors.red.shade400, size: 18),
                  ),
                  title: Text('Delete account', style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.red.shade400)),
                  subtitle: Text('Permanently removes all your data', style: GoogleFonts.nunito(
                      fontSize: 11, color: Colors.red.shade300.withOpacity(0.8))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ),

              // ── Footer ─────────────────────────────────────────────────
              const SizedBox(height: 32),
              Center(child: Text('Kalendr v1.0.0',
                  style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.muted(context)))),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label, style: GoogleFonts.nunito(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: KalendrTheme.muted(context), letterSpacing: 0.6));
  }

  Widget _settingsCard(bool isDark, BuildContext context, AppProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: KalendrTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
          blurRadius: 12, offset: const Offset(0, 2),
        )],
      ),
      child: Column(children: [
        // Appearance
        _themeToggle(context, provider),
        Divider(height: 1, color: KalendrTheme.divider(context)),

        // Notifications toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(
                provider.notificationsEnabled ? Icons.notifications_rounded : Icons.notifications_off_rounded,
                color: kPrimary, size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Text('Notifications', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
            const Spacer(),
            Switch(
              value: provider.notificationsEnabled,
              onChanged: provider.setNotificationsEnabled,
              activeColor: kPrimary,
            ),
          ]),
        ),
        Divider(height: 1, color: KalendrTheme.divider(context)),

        // Log out
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          child: ListTile(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text('Log out?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                  content: Text('You will need to log in again.', style: GoogleFonts.nunito()),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.nunito())),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                        child: Text('Log out', style: GoogleFonts.nunito(color: kPrimary, fontWeight: FontWeight.w700))),
                  ],
                ),
              );
              if (confirm == true) await provider.logout();
            },
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.logout_rounded, color: kPrimary, size: 18),
            ),
            title: Text('Log out', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: kPrimary)),
            trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          ),
        ),
      ]),
    );
  }

  Widget _groupRow(Group g) {
    final color = _groupColor(g);
    return GestureDetector(
      onTap: () => widget.onNavigateToTab?.call(1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: KalendrTheme.surface(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 1),
          )],
        ),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(g.name, style: GoogleFonts.nunito(
              fontSize: 14, fontWeight: FontWeight.w700, color: KalendrTheme.text(context)))),
          Text('${g.members.length} member${g.members.length == 1 ? '' : 's'}',
              style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.muted(context))),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 16, color: color),
        ]),
      ),
    );
  }

  Widget _themeToggle(BuildContext context, AppProvider provider) {
    final mode = provider.themeMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFF8338EC).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.palette_rounded, color: Color(0xFF8338EC), size: 18),
          ),
          const SizedBox(width: 14),
          Text('Appearance', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
        ]),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.all(3),
          child: Row(children: [
            Expanded(child: _themePill(context, provider, ThemeMode.light, Icons.light_mode_rounded, 'Light', mode == ThemeMode.light)),
            Expanded(child: _themePill(context, provider, ThemeMode.system, Icons.phone_android_rounded, 'System', mode == ThemeMode.system)),
            Expanded(child: _themePill(context, provider, ThemeMode.dark, Icons.dark_mode_rounded, 'Dark', mode == ThemeMode.dark)),
          ]),
        ),
      ]),
    );
  }

  Widget _themePill(BuildContext context, AppProvider provider, ThemeMode mode, IconData icon, String label, bool active) {
    return GestureDetector(
      onTap: () => provider.setThemeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? KalendrTheme.surface(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)] : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: active ? const Color(0xFF8338EC) : KalendrTheme.muted(context)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? const Color(0xFF8338EC) : KalendrTheme.muted(context),
          )),
        ]),
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color, {VoidCallback? onTap, bool dimmed = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: KalendrTheme.surface(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2),
          )],
        ),
        child: Column(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (dimmed ? Colors.grey : color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: dimmed ? KalendrTheme.muted(context) : color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.nunito(
              fontSize: 24, fontWeight: FontWeight.w800,
              color: dimmed ? KalendrTheme.muted(context) : KalendrTheme.text(context))),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.muted(context))),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              Icon(Icons.arrow_forward_ios_rounded, size: 9, color: color.withOpacity(0.6)),
            ],
          ]),
        ]),
      ),
    );
  }
}
