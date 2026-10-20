import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../state/auth_controller.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../auth/session_router.dart';
import '../auth/signup_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _user = context.read<AuthController>().user;
  late final _name = TextEditingController(text: _user?.name ?? '');
  late final _phone = TextEditingController(text: _user?.phone ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await guard(
      () => context.read<AuthController>().updateProfile(name: _name.text, phone: _phone.text),
      success: 'Profile updated',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            const PageHeader(title: 'Profile'),
            const SizedBox(height: 12),
            Center(
              child: Hero(
                tag: 'avatar',
                child: Avatar(initials: user?.initials ?? '?', size: 92),
              ),
            ),
            const SizedBox(height: 10),
            Center(child: Text(user?.email ?? '', style: context.text.bodyMedium)),
            if (user != null) Center(child: Text('Member since ${Fmt.monthYear(user.createdAt)}', style: context.text.bodySmall)),
            const SizedBox(height: 24),
            Form(
              key: _form,
              child: Column(
                children: [
                  AppTextField(
                    label: 'Full name',
                    controller: _name,
                    icon: PhosphorIconsRegular.user,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => V.name(v, 'Name'),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Phone number',
                    controller: _phone,
                    icon: PhosphorIconsRegular.phone,
                    keyboardType: TextInputType.phone,
                    validator: V.phone,
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(label: 'Save profile', loading: _saving, onPressed: _save),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const IconTile(icon: PhosphorIconsBold.lockKey, color: AppColors.forest, size: 38, radius: 12),
                    title: Text('Change password', style: context.text.titleSmall),
                    trailing: const Icon(PhosphorIconsBold.caretRight, size: 15),
                    onTap: () => showFormSheet(context, title: 'Change password', child: const _PasswordForm()),
                  ),
                  const Divider(indent: 64),
                  ListTile(
                    leading: const IconTile(icon: PhosphorIconsBold.userMinus, color: AppColors.danger, size: 38, radius: 12),
                    title: Text('Delete account', style: context.text.titleSmall?.copyWith(color: AppColors.danger)),
                    subtitle: const Text('Removes your login and all farm records'),
                    onTap: () async {
                      final ok = await confirm(
                        context,
                        title: 'Delete your account?',
                        message: 'Your login and every farm record on this phone will be permanently deleted. Back up first if you need your data.',
                        confirmLabel: 'Delete forever',
                      );
                      if (!ok || !context.mounted) return;
                      final store = context.read<FarmStore>();
                      final auth = context.read<AuthController>();
                      final done = await guard(() async {
                        await store.clearAllData();
                        await auth.deleteAccount();
                      }, success: 'Account deleted');
                      if (done && context.mounted) await logout(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm();

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await guard(() => context.read<AuthController>().changePassword(_current.text, _next.text), success: 'Password changed');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      children: [
        AppTextField(
          label: 'Current password',
          controller: _current,
          obscure: true,
          icon: PhosphorIconsRegular.lockSimple,
          textCapitalization: TextCapitalization.none,
          validator: (v) => V.required(v, 'Current password'),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'New password',
          controller: _next,
          obscure: true,
          icon: PhosphorIconsRegular.lockSimpleOpen,
          textCapitalization: TextCapitalization.none,
          validator: (v) {
            final e = V.password(v);
            if (e != null) return e;
            return v == _current.text ? 'Use a different password' : null;
          },
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        PasswordStrength(password: _next.text),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Update password', loading: _saving, onPressed: _save),
      ],
    ),
  );
}
