import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import 'auth_header.dart';
import 'forgot_password_screen.dart';
import 'session_router.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: context.read<AuthController>().lastEmail ?? '');
  final _password = TextEditingController();
  bool _remember = true;
  bool _loading = false;
  bool _demoLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().login(_email.text, _password.text, remember: _remember);
      if (mounted) await goToNextStep(context);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// One tap to explore: creates (or opens) a demo account full of sample records.
  Future<void> _demo() async {
    setState(() => _demoLoading = true);
    final auth = context.read<AuthController>();
    final store = context.read<FarmStore>();
    await guard(
      () => withBusy(context, 'Setting up your sample farm…', () async {
        const email = 'demo@shamba.app', pass = 'demo1234';
        try {
          await auth.login(email, pass);
        } on AuthException {
          await auth.signUp(name: 'Demo Farmer', email: email, phone: '0712 000 111', password: pass);
        }
        await store.open(auth.user!.id);
        if (!store.hasFarm) {
          await store.saveFarm(
            FarmProfile(
              name: 'Green Acres Farm',
              location: 'Kiambu, Kenya',
              birdTypes: {BirdType.layers, BirdType.broilers, BirdType.kienyeji},
              defaultTrayPrice: 490,
              size: '3 acres',
            ),
          );
        }
        if (store.isEmpty) await store.loadDemoData();
      }),
      haptic: false,
    );
    if (mounted && store.hasFarm) await goToNextStep(context);
    if (mounted) setState(() => _demoLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back', style: context.text.displaySmall).enter(0),
                      const SizedBox(height: 6),
                      Text('Log in to see how your farm is doing today.', style: context.text.bodyMedium).enter(1),
                      const SizedBox(height: 24),
                      AppTextField(
                        controller: _email,
                        hint: 'Email address',
                        icon: PhosphorIconsRegular.envelopeSimple,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textCapitalization: TextCapitalization.none,
                        validator: V.email,
                      ).enter(2),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _password,
                        hint: 'Password',
                        icon: PhosphorIconsRegular.lockSimple,
                        obscure: true,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.none,
                        validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                        onSubmitted: (_) => _login(),
                      ).enter(3),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: _error == null
                            ? const SizedBox(width: double.infinity)
                            : Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 14),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                                child: Row(
                                  children: [
                                    const Icon(PhosphorIconsFill.warningCircle, color: AppColors.danger, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(_error!, style: context.text.bodyMedium?.copyWith(color: AppColors.danger)),
                                    ),
                                  ],
                                ),
                              ).animate().shakeX(hz: 4, amount: 4, duration: 400.ms),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          MergeSemantics(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => setState(() => _remember = !_remember),
                                  child: Text('Keep me signed in', style: context.text.bodyMedium),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => go(context, ForgotPasswordScreen(email: _email.text)),
                            child: const Text('Forgot password?'),
                          ),
                        ],
                      ).enter(4),
                      const SizedBox(height: 12),
                      PrimaryButton(label: 'Log in', loading: _loading, onPressed: _login).enter(5),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: context.text.bodySmall),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SocialButton(
                        label: 'Explore the demo farm',
                        icon: PhosphorIconsBold.plant,
                        iconColor: AppColors.forest,
                        onPressed: _demoLoading ? () {} : _demo,
                      ).enter(6),
                      const SizedBox(height: 26),
                      Center(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text("Don't have an account? ", style: context.text.bodyMedium),
                            Semantics(
                              button: true,
                              child: GestureDetector(
                                onTap: () => go(context, const SignupScreen()),
                                child: Text('Sign up', style: context.text.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
