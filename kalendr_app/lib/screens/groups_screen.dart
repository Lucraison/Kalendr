import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import '../widgets/slide_route.dart';
import '../l10n/app_strings.dart';
import 'events_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Group> _groups = [];
  bool _loading = true;
  String _error = '';
  final _groupName = TextEditingController();
  final _inviteCode = TextEditingController();
  bool _creating = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final api = context.read<AppProvider>().api;
      _groups = await api.getGroups();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_groupName.text.trim().isEmpty) return;
    setState(() { _creating = true; _error = ''; });
    try {
      final api = context.read<AppProvider>().api;
      final g = await api.createGroup(_groupName.text.trim());
      _groupName.clear();
      setState(() => _groups = [g, ..._groups]);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _join() async {
    if (_inviteCode.text.trim().isEmpty) return;
    setState(() { _joining = true; _error = ''; });
    try {
      final api = context.read<AppProvider>().api;
      final g = await api.joinGroup(_inviteCode.text.trim().toUpperCase());
      _inviteCode.clear();
      if (!_groups.any((x) => x.id == g.id)) setState(() => _groups = [g, ..._groups]);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Color _groupColor(Group g) => groupColorFor(g.id);

  void _showFab() {
    _error = '';
    final s = context.s;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: KalendrTheme.surface(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),

              // Create section
              Text(s.createAGroup, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
                    child: TextField(
                      controller: _groupName,
                      style: GoogleFonts.nunito(color: KalendrTheme.text(context), fontSize: 15),
                      decoration: InputDecoration(
                        hintText: s.groupNameHint,
                        hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 15),
                        prefixIcon: Icon(Icons.group_add_rounded, size: 18, color: KalendrTheme.muted(context)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _creating ? null : () async { setSheet(() {}); await _create(); setSheet(() {}); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: _creating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(s.create, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ]),

              const SizedBox(height: 20),

              // Join section
              Text(s.joinWithInviteCode, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
                    child: TextField(
                      controller: _inviteCode,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.nunito(color: KalendrTheme.text(context), fontSize: 15, letterSpacing: 1.5),
                      decoration: InputDecoration(
                        hintText: 'XXXXXXXX...',
                        hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 15),
                        prefixIcon: Icon(Icons.link_rounded, size: 18, color: KalendrTheme.muted(context)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _joining ? null : () async { setSheet(() {}); await _join(); setSheet(() {}); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: _joining
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(context.s.join, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ]),

              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: GoogleFonts.nunito(color: kPrimary, fontSize: 13), textAlign: TextAlign.center),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KalendrTheme.surface(context),
      body: Column(
        children: [
          Container(
            color: KalendrTheme.surface(context),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 16),
            child: Text(context.s.myGroups, style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
          ),
          Expanded(
            child: RefreshIndicator(
              color: kPrimary,
              onRefresh: _load,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _loading
                  ? _buildSkeleton()
                  : _error.isNotEmpty
                      ? _buildError()
                      : _groups.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                          children: [
                            const SizedBox(height: 60),
                            Center(child: Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(color: kPrimary.withOpacity(0.08), shape: BoxShape.circle),
                              child: const Icon(Icons.people_outline_rounded, size: 40, color: kPrimary),
                            )),
                            const SizedBox(height: 20),
                            Text(context.s.noGroupsYet,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: KalendrTheme.text(context))),
                            const SizedBox(height: 8),
                            Text('Create a group or join one with an invite code to see everyone\'s schedule.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(fontSize: 14, color: KalendrTheme.muted(context))),
                            const SizedBox(height: 32),
                            // Create group inline
                            Text(context.s.createAGroup,
                                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
                                  child: TextField(
                                    controller: _groupName,
                                    style: GoogleFonts.nunito(color: KalendrTheme.text(context), fontSize: 15),
                                    decoration: InputDecoration(
                                      hintText: context.s.groupNameHint,
                                      hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 15),
                                      prefixIcon: Icon(Icons.group_add_rounded, size: 18, color: KalendrTheme.muted(context)),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _creating ? null : _create,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimary, foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20),
                                  ),
                                  child: _creating
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text(context.s.create, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 20),
                            Row(children: [
                              Expanded(child: Divider(color: KalendrTheme.divider(context))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('or', style: GoogleFonts.nunito(fontSize: 13, color: KalendrTheme.muted(context))),
                              ),
                              Expanded(child: Divider(color: KalendrTheme.divider(context))),
                            ]),
                            const SizedBox(height: 20),
                            // Join group inline
                            Text(context.s.joinWithInviteCode,
                                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: KalendrTheme.subtext(context))),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(color: KalendrTheme.field(context), borderRadius: BorderRadius.circular(14)),
                                  child: TextField(
                                    controller: _inviteCode,
                                    textCapitalization: TextCapitalization.characters,
                                    style: GoogleFonts.nunito(color: KalendrTheme.text(context), fontSize: 15, letterSpacing: 1.5),
                                    decoration: InputDecoration(
                                      hintText: 'XXXXXXXX...',
                                      hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context), fontSize: 15),
                                      prefixIcon: Icon(Icons.link_rounded, size: 18, color: KalendrTheme.muted(context)),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _joining ? null : _join,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4ECDC4), foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20),
                                  ),
                                  child: _joining
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text(context.s.join, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
                                ),
                              ),
                            ]),
                            if (_error.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(_error, style: GoogleFonts.nunito(color: kPrimary, fontSize: 13), textAlign: TextAlign.center),
                            ],
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                          children: _groups.map((g) => _groupCard(g)).toList(),
                        ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFab,
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(child: Column(children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(context.s.couldNotLoadGroups, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(context.s.retry, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(foregroundColor: kPrimary),
          ),
        ])),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: KalendrTheme.surface(context),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            Container(width: 5, height: 80, decoration: BoxDecoration(
              color: KalendrTheme.divider(context),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            )),
            const SizedBox(width: 16),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Skeleton(width: 160, height: 14, radius: 7),
                const SizedBox(height: 8),
                Skeleton(width: 80, height: 11, radius: 5),
              ]),
            )),
          ]),
        ),
      )),
    );
  }

  Future<void> _showRenameDialog(Group g) async {
    final ctrl = TextEditingController(text: g.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.s.rename + ' ' + context.s.groups.toLowerCase(), style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.nunito(),
          decoration: InputDecoration(
            hintText: context.s.groupName,
            hintStyle: GoogleFonts.nunito(color: KalendrTheme.muted(context)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            filled: true,
            fillColor: KalendrTheme.field(context),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.s.cancel, style: GoogleFonts.nunito())),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(context.s.rename, style: GoogleFonts.nunito(color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == g.name) return;
    try {
      await context.read<AppProvider>().api.renameGroup(g.id, newName);
      setState(() => g.name = newName);
      if (mounted) {
        showSnack(context, context.s.groupRenamed, color: _groupColor(g));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _leave(Group g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.s.leaveGroupConfirm(g.name), style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(context.s.rejoinWithInviteCode, style: GoogleFonts.nunito()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.s.cancel, style: GoogleFonts.nunito())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.s.leave, style: GoogleFonts.nunito(color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await context.read<AppProvider>().api.leaveGroup(g.id);
      setState(() => _groups.removeWhere((x) => x.id == g.id));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Widget _groupCard(Group g) {
    final color = _groupColor(g);
    return Dismissible(
      key: ValueKey(g.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _leave(g);
        return false;
      },
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: kPrimary,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(context, slideRoute(EventsScreen(group: g))),
        onLongPress: () { HapticFeedback.mediumImpact(); _showRenameDialog(g); },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: KalendrTheme.surface(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            )],
          ),
          child: Row(children: [
            Container(
              width: 5,
              height: 80,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.name, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: KalendrTheme.text(context))),
                  const SizedBox(height: 8),
                  Row(children: [
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: g.inviteCode));
                        showSnack(context, context.s.inviteCodeCopied, color: color);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Row(children: [
                          Icon(Icons.copy_rounded, size: 11, color: color),
                          const SizedBox(width: 4),
                          Text(g.inviteCode, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Share.share('Join my group "${g.name}" on Chalk!\nInvite code: ${g.inviteCode}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Row(children: [
                          Icon(Icons.share_rounded, size: 11, color: color),
                          const SizedBox(width: 4),
                          Text(context.s.share, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.people_rounded, size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 3),
                    Text('${g.members.length}', style: GoogleFonts.nunito(fontSize: 12, color: KalendrTheme.muted(context))),
                  ]),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(Icons.chevron_right_rounded, color: color, size: 22),
            ),
          ]),
        ),
      ),
    );
  }
}
