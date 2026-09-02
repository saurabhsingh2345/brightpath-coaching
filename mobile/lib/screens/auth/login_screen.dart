import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/brand.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../widgets/states.dart';
import '../../widgets/theme_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthState>();
    final ok = await auth.login(_email.text, _password.text);
    if (!mounted) return;
    if (!ok && auth.error != null) {
      showSnack(context, auth.error!, isError: true);
      auth.clearError();
    }
  }

  void _useDemo(String email, String password) {
    _email.text = email;
    _password.text = password;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = context.watch<AuthState>().busy;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.xl,
              vertical: Gap.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── logo ──
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.primary,
                              scheme.primary.withValues(alpha: 0.72),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.28),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(Brand.logo, color: Colors.white, size: 38),
                      ),
                    ),
                    const SizedBox(height: Gap.xl),
                    Text(
                      Brand.fullName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      Brand.tagline,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: Gap.xxl + Gap.sm),

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@brightpath.edu',
                        prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Enter your email';
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Gap.lg),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      enabled: !busy,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon:
                            const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v ?? '').isEmpty
                          ? 'Enter your password'
                          : (v!.length < 4 ? 'Password is too short' : null),
                    ),
                    const SizedBox(height: Gap.xl),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Log in'),
                    ),

                    const SizedBox(height: Gap.xxl),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: Gap.md),
                          child: Text(
                            'Demo accounts',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: Gap.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _DemoButton(
                            label: 'Admin',
                            icon: Icons.admin_panel_settings_outlined,
                            onTap: busy
                                ? null
                                : () => _useDemo(
                                    'admin@brightpath.edu', 'Admin@123'),
                          ),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: _DemoButton(
                            label: 'Student',
                            icon: Icons.person_outline_rounded,
                            onTap: busy
                                ? null
                                : () => _useDemo(
                                    'aarav@brightpath.edu', 'Student@123'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
            // Last in the Stack so it paints above the scrolling form and
            // stays tappable.
            const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(top: Gap.sm, right: Gap.sm),
                child: ThemeToggleButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
    );
  }
}
