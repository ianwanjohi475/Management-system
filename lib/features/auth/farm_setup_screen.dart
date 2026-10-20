import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/auth_controller.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../shell/main_shell.dart';
import 'session_router.dart';

const currencies = [
  ('KES', 'Kenyan Shilling'),
  ('UGX', 'Ugandan Shilling'),
  ('TZS', 'Tanzanian Shilling'),
  ('RWF', 'Rwandan Franc'),
  ('NGN', 'Nigerian Naira'),
  ('GHS', 'Ghanaian Cedi'),
  ('ZAR', 'South African Rand'),
  ('USD', 'US Dollar'),
];

/// Two quick steps after sign-up. Also used from Settings to edit the farm.
class FarmSetupScreen extends StatefulWidget {
  const FarmSetupScreen({super.key, this.editing = false});
  final bool editing;

  @override
  State<FarmSetupScreen> createState() => _FarmSetupScreenState();
}

class _FarmSetupScreenState extends State<FarmSetupScreen> {
  final _form = GlobalKey<FormState>();
  late final FarmProfile? _existing = context.read<FarmStore>().farm;
  late final _name = TextEditingController(text: _existing?.name ?? '');
  late final _location = TextEditingController(text: _existing?.location ?? '');
  late final _size = TextEditingController(text: _existing?.size ?? '');
  late final _trayPrice = TextEditingController(text: (_existing?.defaultTrayPrice ?? 450).toStringAsFixed(0));
  late bool _pigs = _existing?.keepsPigs ?? true;
  late final Set<BirdType> _birds = {
    ...(_existing?.birdTypes ?? {BirdType.layers}),
  };
  late String _currency = _existing?.currency ?? 'KES';
  late int _perTray = _existing?.eggsPerTray ?? 30;
  bool _sample = false;
  int _step = 0;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _location, _size, _trayPrice]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      if (_form.currentState?.validate() ?? false) setState(() => _step = 1);
      return;
    }
    if (!_pigs && _birds.isEmpty) {
      showToast('Choose at least one animal you keep.', type: ToastType.error);
      return;
    }
    final price = V.parse(_trayPrice.text)?.toDouble() ?? 0;
    if (_birds.any((b) => b.laysEggs) && price <= 0) {
      showToast('Enter your usual price for a tray of eggs.', type: ToastType.error);
      return;
    }
    setState(() => _saving = true);
    final store = context.read<FarmStore>();
    final base = _existing ?? FarmProfile(name: '', location: '');
    final ok = await guard(() async {
      await store.saveFarm(
        base.copyWith(
          name: _name.text.trim(),
          location: _location.text.trim(),
          size: _size.text.trim(),
          keepsPigs: _pigs,
          birdTypes: _birds,
          currency: _currency,
          eggsPerTray: _perTray,
          defaultTrayPrice: price,
        ),
      );
      if (_sample && store.isEmpty && mounted) await withBusy(context, 'Adding sample records…', store.loadDemoData);
    }, success: widget.editing ? 'Farm details saved' : null);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    if (widget.editing) {
      Navigator.pop(context);
    } else {
      replaceAll(context, const MainShell());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1) setState(() => _step = 0);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
                child: Row(
                  children: [
                    if (_step == 1 || widget.editing)
                      CircleIconButton(icon: PhosphorIconsBold.caretLeft, onTap: () => _step == 1 ? setState(() => _step = 0) : Navigator.pop(context))
                    else
                      Image.asset(Assets.logoMark, height: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          for (var i = 0; i < 2; i++)
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: i <= _step ? Theme.of(context).colorScheme.primary : context.palette.border,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${_step + 1}/2', style: context.text.labelMedium),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  child: _step == 0 ? _stepOne(context, user?.firstName) : _stepTwo(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: PrimaryButton(
                  label: _step == 0 ? 'Continue' : (widget.editing ? 'Save changes' : 'Finish setup'),
                  icon: _step == 0 ? PhosphorIconsBold.arrowRight : PhosphorIconsBold.check,
                  loading: _saving,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepOne(BuildContext context, String? name) => SingleChildScrollView(
    key: const ValueKey(0),
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.editing ? 'Farm details' : 'Karibu${name == null ? '' : ', $name'}!', style: context.text.displaySmall).enter(0),
          const SizedBox(height: 8),
          Text('Tell us about your farm. You can change this later.', style: context.text.bodyMedium).enter(1),
          const SizedBox(height: 28),
          AppTextField(
            label: 'Farm name',
            controller: _name,
            hint: 'e.g. Wanjohi Farm',
            icon: PhosphorIconsRegular.barn,
            textCapitalization: TextCapitalization.words,
            validator: (v) => V.name(v, 'Farm name'),
          ).enter(2),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Location',
            controller: _location,
            hint: 'e.g. Kiambu, Kenya',
            icon: PhosphorIconsRegular.mapPin,
            textCapitalization: TextCapitalization.words,
            validator: (v) => V.required(v, 'Location'),
          ).enter(3),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Farm size',
            controller: _size,
            hint: 'e.g. 2 acres',
            icon: PhosphorIconsRegular.ruler,
            optional: true,
            textInputAction: TextInputAction.done,
          ).enter(4),
          const SizedBox(height: 16),
          SelectField<String>(
            label: 'Currency',
            value: _currency,
            icon: PhosphorIconsRegular.coins,
            options: [for (final c in currencies) PickerOption(c.$1, '${c.$1} · ${c.$2}')],
            onChanged: (v) => setState(() => _currency = v),
          ).enter(5),
        ],
      ),
    ),
  );

  Widget _stepTwo(BuildContext context) => SingleChildScrollView(
    key: const ValueKey(1),
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What do you keep?', style: context.text.displaySmall).enter(0),
        const SizedBox(height: 8),
        Text("Pick everything on your farm. We'll set up the right records.", style: context.text.bodyMedium).enter(1),
        const SizedBox(height: 24),
        GridView.count(
          padding: EdgeInsets.zero,
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            _AnimalCard(image: Assets.catPigs, title: 'Pigs', subtitle: 'Sows, boars, growers', selected: _pigs, onTap: () => setState(() => _pigs = !_pigs)),
            for (final b in BirdType.values)
              _AnimalCard(
                image: b.image,
                title: b.label,
                subtitle: b.hint,
                selected: _birds.contains(b),
                onTap: () => setState(() => _birds.contains(b) ? _birds.remove(b) : _birds.add(b)),
              ),
          ].indexed.map((e) => e.$2.enter(e.$1 + 2)).toList(),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: _birds.any((b) => b.laysEggs)
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Usual tray price',
                          controller: _trayPrice,
                          prefixText: '$_currency ',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: AppTextField.decimal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SelectField<int>(
                          label: 'Eggs per tray',
                          value: _perTray,
                          icon: PhosphorIconsRegular.egg,
                          options: const [PickerOption(30, '30 eggs'), PickerOption(20, '20 eggs'), PickerOption(12, '12 eggs (dozen)')],
                          onChanged: (v) => setState(() => _perTray = v),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (!widget.editing) ...[
          const SizedBox(height: 20),
          AppCard(
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _sample,
              onChanged: (v) => setState(() => _sample = v),
              title: const Text('Add sample records'),
              subtitle: const Text('Explore the app with example pigs, flocks and sales. You can clear them later in Settings.'),
            ),
          ),
        ],
      ],
    ),
  );
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.image, required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String image;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final primary = Theme.of(context).colorScheme.primary;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? p.brandTint : p.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? primary : p.border, width: selected ? 2 : 1),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: Image.asset(image).animate(target: selected ? 1 : 0).scaleXY(end: 1.08, duration: 250.ms),
                  ),
                ),
                const SizedBox(height: 8),
                Text(title, style: context.text.titleMedium),
                Text(subtitle, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? primary : p.border, width: 1.6),
                ),
                child: selected ? Icon(PhosphorIconsBold.check, size: 14, color: context.isDark ? AppColors.forestDeep : Colors.white) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
