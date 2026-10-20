import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/assets.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../state/auth_controller.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../alerts/alerts_screen.dart';
import '../auth/farm_setup_screen.dart';
import '../auth/session_router.dart';
import '../customers/customers_screen.dart';
import '../finance/expenses_screen.dart';
import '../health/health_screen.dart';
import '../inventory/inventory_screen.dart';
import '../pigs/breeding_screen.dart';
import '../poultry/egg_log_screen.dart';
import '../tasks/tasks_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _backup(BuildContext context) async {
    final store = context.read<FarmStore>();
    await guard(() async {
      final json = const JsonEncoder.withIndent(' ').convert(store.exportBackup());
      final name = 'shamba-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json';
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(utf8.encode(json), mimeType: 'application/json', name: name)],
            fileNameOverrides: [name],
            subject: 'Shamba backup',
          ),
        );
      } catch (_) {
        throw const PlatformFeatureException('Could not open the share sheet on this device.');
      }
    }, haptic: false);
  }

  Future<void> _restore(BuildContext context) async {
    final store = context.read<FarmStore>();
    final ok = await confirm(
      context,
      title: 'Restore from backup?',
      message: 'Everything currently on this phone will be replaced by the backup file.',
      confirmLabel: 'Choose file',
      destructive: false,
      icon: PhosphorIconsBold.clockCounterClockwise,
    );
    if (!ok) return;
    await guard(() async {
      PlatformFile? file;
      try {
        file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
      } catch (_) {
        throw const PlatformFeatureException('Could not open your files.');
      }
      if (file == null) return;
      final bytes = await file.readAsBytes().catchError((_) => throw const ValidationException('Could not read that file.'));
      if (!context.mounted) return;
      final skipped = await withBusy(context, 'Restoring your farm…', () => store.importBackup(utf8.decode(bytes, allowMalformed: true)));
      showToast(skipped == 0 ? 'Backup restored' : 'Backup restored. $skipped damaged records were skipped.');
    }, haptic: false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final store = context.watch<FarmStore>();
    final user = auth.user;
    final farm = store.farm;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            const PageHeader(title: 'Settings').enter(0),
            const SizedBox(height: 8),
            AppCard(
              onTap: () => go(context, const ProfileScreen()),
              gradient: AppColors.heroGradient,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Hero(
                    tag: 'avatar',
                    child: Avatar(initials: user?.initials ?? '?', size: 58, color: AppColors.lime),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '',
                          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(fontFamily: 'Inter', color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5),
                        ),
                        const SizedBox(height: 6),
                        StatusPill(farm?.name ?? 'My farm', color: AppColors.amber, icon: PhosphorIconsBold.barn, solid: true),
                      ],
                    ),
                  ),
                  const Icon(PhosphorIconsBold.caretRight, color: Colors.white, size: 18),
                ],
              ),
            ).enter(1),
            _Group(
              title: 'Farm',
              children: [
                _Tile(
                  icon: PhosphorIconsBold.barn,
                  color: AppColors.forest,
                  title: 'Farm details',
                  subtitle: farm?.location,
                  onTap: () => go(context, const FarmSetupScreen(editing: true)),
                ),
                if (farm?.keepsPigs ?? true)
                  _Tile(
                    icon: PhosphorIconsBold.heart,
                    color: AppColors.pinkDeep,
                    title: 'Breeding & litters',
                    onTap: () => go(context, const BreedingScreen()),
                  ),
                _Tile(icon: PhosphorIconsBold.egg, color: AppColors.amber, title: 'Egg log', onTap: () => go(context, const EggLogScreen())),
                _Tile(icon: PhosphorIconsBold.syringe, color: AppColors.info, title: 'Health & vaccinations', onTap: () => go(context, const HealthScreen())),
                _Tile(icon: PhosphorIconsBold.grains, color: AppColors.warning, title: 'Feed & store', onTap: () => go(context, const InventoryScreen())),
                _Tile(icon: PhosphorIconsBold.wallet, color: AppColors.pinkDeep, title: 'Expenses', onTap: () => go(context, const ExpensesScreen())),
                _Tile(icon: PhosphorIconsBold.usersThree, color: AppColors.forest, title: 'Customers', onTap: () => go(context, const CustomersScreen())),
                _Tile(icon: PhosphorIconsBold.checkSquare, color: AppColors.lime, title: 'Tasks', onTap: () => go(context, const TasksScreen())),
                _Tile(
                  icon: PhosphorIconsBold.bell,
                  color: AppColors.danger,
                  title: 'Alerts',
                  trailing: store.alerts.isEmpty ? null : StatusPill('${store.alerts.length}', color: AppColors.danger, solid: true),
                  onTap: () => go(context, const AlertsScreen()),
                ),
              ],
            ),
            _Group(
              title: 'Appearance',
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ChoicePills<ThemeMode>(
                    value: auth.themeMode,
                    onChanged: auth.setThemeMode,
                    options: const [
                      PickerOption(ThemeMode.light, 'Light', icon: PhosphorIconsBold.sun),
                      PickerOption(ThemeMode.dark, 'Dark', icon: PhosphorIconsBold.moon),
                      PickerOption(ThemeMode.system, 'Auto', icon: PhosphorIconsBold.deviceMobile),
                    ],
                  ),
                ),
              ],
            ),
            _Group(
              title: 'Your data',
              children: [
                _Tile(
                  icon: PhosphorIconsBold.cloudArrowUp,
                  color: AppColors.info,
                  title: 'Back up data',
                  subtitle: 'Save a file to Drive, WhatsApp or email',
                  onTap: () => _backup(context),
                ),
                _Tile(icon: PhosphorIconsBold.clockCounterClockwise, color: AppColors.forest, title: 'Restore from backup', onTap: () => _restore(context)),
                if (store.isEmpty)
                  _Tile(
                    icon: PhosphorIconsBold.sparkle,
                    color: AppColors.amber,
                    title: 'Load sample farm',
                    subtitle: 'Explore the app with example records',
                    onTap: () => guard(() => withBusy(context, 'Setting up your sample farm…', store.loadDemoData), success: 'Sample data loaded'),
                  ),
                _Tile(
                  icon: PhosphorIconsBold.trash,
                  color: AppColors.danger,
                  title: 'Clear all farm records',
                  subtitle: 'Keeps your account and farm details',
                  onTap: () async {
                    if (await confirm(
                      context,
                      title: 'Clear all records?',
                      message: 'All pigs, flocks, sales and other records will be deleted. Back up first if you might need them.',
                      confirmLabel: 'Clear',
                    )) {
                      await guard(store.clearAllData, success: 'All records cleared');
                    }
                  },
                ),
              ],
            ),
            _Group(
              title: 'Account',
              children: [
                _Tile(
                  icon: PhosphorIconsBold.userCircle,
                  color: AppColors.forest,
                  title: 'Profile & password',
                  onTap: () => go(context, const ProfileScreen()),
                ),
                _Tile(
                  icon: PhosphorIconsBold.signOut,
                  color: AppColors.warning,
                  title: 'Log out',
                  onTap: () async {
                    if (await confirm(
                      context,
                      title: 'Log out?',
                      message: 'Your data stays safe on this phone.',
                      confirmLabel: 'Log out',
                      destructive: false,
                      icon: PhosphorIconsBold.signOut,
                    )) {
                      if (context.mounted) await logout(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 28),
            Center(child: Image.asset(Assets.logoWordmark, height: 36)),
            const SizedBox(height: 6),
            Center(child: Text('Version 1.0.0 · Made for farmers', style: context.text.bodySmall)),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Text(title.toUpperCase(), style: context.text.labelSmall?.copyWith(letterSpacing: 1.4)),
      ),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(indent: 64), children[i]],
          ],
        ),
      ),
    ],
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.color, required this.title, this.subtitle, this.onTap, this.trailing});
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: IconTile(icon: icon, color: color, size: 38, radius: 12),
    title: Text(title, style: context.text.titleSmall),
    subtitle: subtitle == null || subtitle!.isEmpty ? null : Text(subtitle!),
    trailing: trailing ?? Icon(PhosphorIconsBold.caretRight, size: 15, color: context.palette.inkMuted),
  );
}
