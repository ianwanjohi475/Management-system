import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/validators.dart';
import '../../state/auth_controller.dart';
import '../../widgets/widgets.dart';
import 'auth_header.dart';
import 'session_router.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agree = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!_agree) {
      setState(() => _error = 'Please accept that your records are stored on this phone.');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().signUp(name: _name.text, email: _email.text, phone: _phone.text, password: _password.text);
      if (mounted) await goToNextStep(context);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHeader(showBack: true, compact: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create account', style: context.text.displaySmall).enter(0),
                      const SizedBox(height: 6),
                      Text('Set up your farm in under a minute.', style: context.text.bodyMedium).enter(1),
                      const SizedBox(height: 24),
                      AppTextField(
                        label: 'Full name',
                        controller: _name,
                        hint: 'e.g. Ian Wanjohi',
                        icon: PhosphorIconsRegular.user,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        validator: (v) => V.name(v, 'Name'),
                      ).enter(2),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Email',
                        controller: _email,
                        hint: 'you@example.com',
                        icon: PhosphorIconsRegular.envelopeSimple,
                        keyboardType: TextInputType.emailAddress,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: const [AutofillHints.email],
                        validator: V.email,
                      ).enter(3),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Phone number',
                        controller: _phone,
                        hint: '0712 345 678',
                        icon: PhosphorIconsRegular.phone,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        validator: V.phone,
                      ).enter(4),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 6),
                        child: Text('Used to reset your password, so keep it correct.', style: context.text.bodySmall),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Password',
                        controller: _password,
                        hint: 'At least 6 characters',
                        icon: PhosphorIconsRegular.lockSimple,
                        obscure: true,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: V.password,
                        onChanged: (_) => setState(() {}),
                      ).enter(5),
                      const SizedBox(height: 10),
                      PasswordStrength(password: _password.text),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Confirm password',
                        controller: _confirm,
                        hint: 'Type it again',
                        icon: PhosphorIconsRegular.lockSimpleOpen,
                        obscure: true,
                        textCapitalization: TextCapitalization.none,
                        textInputAction: TextInputAction.done,
                        validator: (v) => v != _password.text ? "Passwords don't match" : null,
                        onSubmitted: (_) => _submit(),
                      ).enter(6),
                      const SizedBox(height: 16),
                      MergeSemantics(
                        child: GestureDetector(
                          onTap: () => setState(() => _agree = !_agree),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 28,
                                child: Checkbox(value: _agree, onChanged: (v) => setState(() => _agree = v ?? false)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'I understand my farm records are saved on this phone and I should back them up from Settings.',
                                    style: context.text.bodySmall?.copyWith(color: context.palette.inkSoft),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
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
                        ),
                      ],
                      const SizedBox(height: 22),
                      PrimaryButton(label: 'Create account', loading: _loading, onPressed: _submit),
                      const SizedBox(height: 22),
                      Center(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Already have an account? ', style: context.text.bodyMedium),
                            Semantics(
                              button: true,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text('Log in', style: context.text.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
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

class PasswordStrength extends StatelessWidget {
  const PasswordStrength({super.key, required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    var score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 10) score++;
    if (RegExp(r'[0-9]').hasMatch(password) && RegExp(r'[A-Za-z]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password) || RegExp(r'[A-Z]').hasMatch(password)) score++;
    final (label, color) = switch (score) {
      0 => ('Too short', AppColors.danger),
      1 => ('Weak', AppColors.danger),
      2 => ('Okay', AppColors.warning),
      3 => ('Good', AppColors.lime),
      _ => ('Strong', AppColors.success),
    };
    if (password.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 5,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(color: i < score ? color : context.palette.border, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        const SizedBox(width: 8),
        Text(label, style: context.text.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}
