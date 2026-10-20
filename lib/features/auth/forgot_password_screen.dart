import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/validators.dart';
import '../../state/auth_controller.dart';
import '../../widgets/widgets.dart';
import 'signup_screen.dart';

/// Offline password reset: email + the phone number used at sign-up.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});
  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().resetPassword(email: _email.text, phone: _phone.text, newPassword: _password.text);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: ''),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                child: _done ? _success(context) : _formView(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _success(BuildContext context) => Padding(
    key: const ValueKey('done'),
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Spacer(),
        Image.asset(Assets.successPig, height: 190).animate().scale(curve: Curves.elasticOut, duration: 900.ms),
        const SizedBox(height: 24),
        Text('Password updated', style: context.text.displaySmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('You can now log in with your new password.', style: context.text.bodyMedium, textAlign: TextAlign.center),
        const Spacer(),
        PrimaryButton(label: 'Back to log in', onPressed: () => Navigator.pop(context)),
      ],
    ),
  );

  Widget _formView(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('form'),
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(icon: PhosphorIconsBold.lockKeyOpen, color: AppColors.forest, size: 64, radius: 20).enter(0),
          const SizedBox(height: 20),
          Text('Reset password', style: context.text.displaySmall).enter(1),
          const SizedBox(height: 8),
          Text(
            'Your account lives on this phone. Confirm the email and phone number you signed up with, then choose a new password.',
            style: context.text.bodyMedium,
          ).enter(2),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Email',
            controller: _email,
            icon: PhosphorIconsRegular.envelopeSimple,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            validator: V.email,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Phone number',
            controller: _phone,
            hint: '0712 345 678',
            icon: PhosphorIconsRegular.phone,
            keyboardType: TextInputType.phone,
            validator: V.phone,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'New password',
            controller: _password,
            icon: PhosphorIconsRegular.lockSimple,
            obscure: true,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.done,
            validator: V.password,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
          PasswordStrength(password: _password.text),
          if (_error != null) ...[
            const SizedBox(height: 14),
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
            ).animate().shakeX(hz: 4, amount: 4, duration: 400.ms),
          ],
          const SizedBox(height: 24),
          PrimaryButton(label: 'Reset password', loading: _loading, onPressed: _submit),
        ],
      ),
    ),
  );
}
