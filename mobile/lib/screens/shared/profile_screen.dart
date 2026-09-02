import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_exception.dart';
import '../../core/brand.dart';
import '../../core/config.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';
import '../admin/clear_demo_screen.dart';

/// Profile + settings, shared by both roles. Students see their enrolment
/// details; admins see their account only.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.showAppBar = true});
  final bool showAppBar;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AsyncController<Map<String, dynamic>> _ctrl;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _ctrl = AsyncController(api.meFull)..load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _editProfile(String name, String? phone) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(name: name, phone: phone),
    );
    if (saved == true && mounted) {
      await context.read<AuthState>().refreshUser();
      _ctrl.load();
    }
  }

  Future<void> _changePassword() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _logout() async {
    final ok = await confirm(
      context,
      title: 'Log out?',
      message: 'You will need your email and password to sign back in.',
      confirmLabel: 'Log out',
    );
    if (!ok) return;
    if (!mounted) return;
    await context.read<AuthState>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final body = ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        if (_ctrl.isFirstLoad) return const LoadingView();
        if (_ctrl.error != null && !_ctrl.hasData) {
          return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
        }
        final me = _ctrl.data!;
        final name = me['name']?.toString() ?? '';
        final email = me['email']?.toString() ?? '';
        final phone = me['phone']?.toString();
        final role = me['role']?.toString() ?? 'STUDENT';
        final student = me['student'] is Map
            ? Map<String, dynamic>.from(me['student'] as Map)
            : null;
        final batch = student?['batch'] is Map
            ? Map<String, dynamic>.from(student!['batch'] as Map)
            : null;

        return RefreshIndicator(
          onRefresh: _ctrl.refresh,
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.xl),
                  child: Column(
                    children: [
                      InitialsAvatar(name: name, size: 76),
                      const SizedBox(height: Gap.lg),
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: Gap.xs),
                      Text(
                        email,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: Gap.md),
                      StatusPill(
                        label: role == 'ADMIN' ? 'ADMINISTRATOR' : 'STUDENT',
                        color: role == 'ADMIN'
                            ? scheme.primary
                            : const Color(0xFF12B76A),
                        icon: role == 'ADMIN'
                            ? Icons.shield_rounded
                            : Icons.school_rounded,
                      ),
                      const SizedBox(height: Gap.xl),
                      OutlinedButton.icon(
                        onPressed: () => _editProfile(name, phone),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit profile'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: Gap.lg),
              InfoCard(
                title: 'ACCOUNT',
                children: [
                  DetailRow(
                    label: 'Phone',
                    value: phone?.isNotEmpty == true ? phone! : 'Not set',
                    icon: Icons.phone_outlined,
                  ),
                  const Divider(),
                  DetailRow(
                    label: 'Member since',
                    value: Fmt.date(me['createdAt']),
                    icon: Icons.event_outlined,
                  ),
                  const Divider(),
                  DetailRow(
                    label: 'Last login',
                    value: Fmt.dateTime(me['lastLoginAt']),
                    icon: Icons.login_rounded,
                  ),
                ],
              ),

              if (student != null) ...[
                const SizedBox(height: Gap.lg),
                InfoCard(
                  title: 'ENROLMENT',
                  children: [
                    DetailRow(
                      label: 'Student ID',
                      value: student['studentCode']?.toString() ?? '—',
                      icon: Icons.badge_outlined,
                    ),
                    const Divider(),
                    DetailRow(
                      label: 'Course',
                      value: student['course']?.toString() ?? '—',
                      icon: Icons.menu_book_outlined,
                    ),
                    const Divider(),
                    DetailRow(
                      label: 'Batch',
                      value: batch == null
                          ? 'Not assigned'
                          : '${batch['name']} · ${batch['timing'] ?? ''}',
                      icon: Icons.groups_outlined,
                    ),
                    const Divider(),
                    DetailRow(
                      label: 'Room',
                      value: batch?['room']?.toString() ?? '—',
                      icon: Icons.room_outlined,
                    ),
                    const Divider(),
                    DetailRow(
                      label: 'Admission date',
                      value: Fmt.date(student['admissionDate']),
                      icon: Icons.event_available_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                InfoCard(
                  title: 'PARENT / GUARDIAN',
                  children: [
                    DetailRow(
                      label: 'Name',
                      value: student['parentName']?.toString() ?? '—',
                      icon: Icons.escalator_warning_outlined,
                    ),
                    const Divider(),
                    DetailRow(
                      label: 'Phone',
                      value: student['parentPhone']?.toString() ?? '—',
                      icon: Icons.phone_outlined,
                    ),
                    const Divider(),
                    DetailRow(
                      label: 'Address',
                      value: student['address']?.toString() ?? '—',
                      icon: Icons.location_on_outlined,
                    ),
                  ],
                ),
              ],

              const SizedBox(height: Gap.lg),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline_rounded, size: 21),
                      title: const Text('Change password'),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: _changePassword,
                    ),
                    if (role == 'ADMIN') ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.cleaning_services_outlined,
                            size: 21),
                        title: const Text('Start fresh'),
                        subtitle: const Text(
                          'Remove the sample walkthrough data',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing:
                            const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClearDemoScreen(),
                          ),
                        ),
                      ),
                    ],
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.logout_rounded,
                          size: 21, color: scheme.error),
                      title: Text('Log out',
                          style: TextStyle(color: scheme.error)),
                      onTap: _logout,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Gap.xl),
              Center(
                child: Column(
                  children: [
                    Icon(Brand.logo, size: 22, color: scheme.onSurfaceVariant),
                    const SizedBox(height: Gap.sm),
                    Text(
                      '${Brand.fullName} · v1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppConfig.apiBaseUrl,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10.5,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: body,
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.name, this.phone});
  final String name;
  final String? phone;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late final _phone = TextEditingController(text: widget.phone ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().updateMe(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
          );
      if (!mounted) return;
      showSnack(context, 'Profile updated');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Gap.xl,
        right: Gap.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.xl,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit profile',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Gap.xl),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Name is required';
                if (value.length < 2) return 'Name is too short';
                return null;
              },
            ),
            const SizedBox(height: Gap.lg),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final msg = await context
          .read<ApiService>()
          .changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.pop(context, true);
      showSnack(context, msg);
      // The server revoked every refresh token, so sign out locally too.
      await context.read<AuthState>().logout();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Gap.xl,
        right: Gap.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.xl,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Change password',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Gap.xs),
            Text(
              'You will be signed out of every device afterwards.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: Gap.xl),
            TextFormField(
              controller: _current,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Current password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your current password' : null,
            ),
            const SizedBox(height: Gap.lg),
            TextFormField(
              controller: _next,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: (v) => (v == null || v.length < 6)
                  ? 'Use at least 6 characters'
                  : null,
            ),
            const SizedBox(height: Gap.lg),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration:
                  const InputDecoration(labelText: 'Confirm new password'),
              validator: (v) =>
                  v != _next.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}
