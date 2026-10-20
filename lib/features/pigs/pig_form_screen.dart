import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';

/// Picks a photo and returns it as a small base64 JPEG, or null if cancelled.
Future<String?> pickPhoto(BuildContext context) async {
  final source = await showOptionsSheet<ImageSource>(
    context,
    title: 'Add a photo',
    options: const [
      PickerOption(ImageSource.camera, 'Take a photo', icon: PhosphorIconsBold.camera),
      PickerOption(ImageSource.gallery, 'Choose from gallery', icon: PhosphorIconsBold.image),
    ],
  );
  if (source == null) return null;
  try {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 640, maxHeight: 640, imageQuality: 72);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 600 * 1024) throw const PlatformFeatureException('That photo is too large. Try another one.');
    return base64Encode(bytes);
  } on AppException {
    rethrow;
  } catch (e) {
    throw PlatformFeatureException(
      source == ImageSource.camera
          ? 'Could not open the camera. Allow camera access in your phone settings.'
          : 'Could not open your photos. Allow photo access in your phone settings.',
    );
  }
}

class PigFormScreen extends StatefulWidget {
  const PigFormScreen({super.key, this.pig});
  final Pig? pig;

  @override
  State<PigFormScreen> createState() => _PigFormScreenState();
}

class _PigFormScreenState extends State<PigFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Pig? _p = widget.pig;
  late final _tag = TextEditingController(text: _p?.tag ?? context.read<FarmStore>().suggestPigTag());
  late final _name = TextEditingController(text: _p?.name ?? '');
  late final _pen = TextEditingController(text: _p?.pen ?? '');
  late final _price = TextEditingController(text: _p?.purchasePrice?.toStringAsFixed(0) ?? '');
  late final _notes = TextEditingController(text: _p?.notes ?? '');
  final _weight = TextEditingController();
  late Sex _sex = _p?.sex ?? Sex.female;
  late PigStage _stage = _p?.stage ?? PigStage.grower;
  late String? _breed = _p?.breed;
  late DateTime? _birth = _p?.birthDate;
  late DateTime _acquired = _p?.acquiredDate ?? DateTime.now();
  late bool _purchased = _p?.purchased ?? false;
  late String? _motherId = _p?.motherId;
  late String? _fatherId = _p?.fatherId;
  late String? _photo = _p?.photo;
  bool _saving = false;

  bool get _editing => _p != null;

  @override
  void dispose() {
    for (final c in [_tag, _name, _pen, _price, _notes, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onStage(PigStage s) {
    setState(() {
      _stage = s;
      if (s == PigStage.sow || s == PigStage.gilt) _sex = Sex.female;
      if (s == PigStage.boar) _sex = Sex.male;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) {
      showToast('Please fix the highlighted fields.', type: ToastType.error);
      return;
    }
    setState(() => _saving = true);
    final store = context.read<FarmStore>();
    final now = DateTime.now();
    final pig = Pig(
      id: _p?.id ?? newId(),
      tag: _tag.text.trim(),
      name: _name.text.trim(),
      sex: _sex,
      breed: _breed ?? 'Other',
      stage: _stage,
      birthDate: _birth,
      acquiredDate: _acquired,
      purchased: _purchased,
      purchasePrice: _purchased ? V.parse(_price.text)?.toDouble() : null,
      pen: _pen.text.trim(),
      status: _p?.status ?? PigStatus.active,
      statusDate: _p?.statusDate,
      statusNote: _p?.statusNote ?? '',
      motherId: _motherId,
      fatherId: _fatherId,
      photo: _photo,
      notes: _notes.text.trim(),
      createdAt: _p?.createdAt ?? now,
    );
    final ok = await guard(
      () => store.savePig(pig, initialWeight: _editing ? null : V.parse(_weight.text)?.toDouble()),
      success: _editing ? 'Changes saved' : '${pig.displayName} added to the herd',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, pig.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<FarmStore>();
    final sows = store.pigs.where((p) => p.sex == Sex.female && p.id != _p?.id && (p.stage == PigStage.sow || p.stage == PigStage.gilt)).toList();
    final boars = store.pigs.where((p) => p.sex == Sex.male && p.id != _p?.id && p.stage == PigStage.boar).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: _editing ? 'Edit pig' : 'Add a pig', subtitle: _editing ? _p!.displayName : 'Fill in what you know. You can update later.'),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Center(
                      child: Pressable(
                        onTap: () async {
                          try {
                            final ph = await pickPhoto(context);
                            if (ph != null) setState(() => _photo = ph);
                          } catch (e) {
                            showToast(friendlyError(e), type: ToastType.error);
                          }
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            PigPhoto(photo: _photo, size: 120, radius: 32, young: _stage.isYoung),
                            Positioned(
                              right: -6,
                              bottom: -6,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.forest,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.palette.background, width: 3),
                                ),
                                child: const Icon(PhosphorIconsBold.camera, color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_photo != null)
                      Center(
                        child: TextButton(onPressed: () => setState(() => _photo = null), child: const Text('Remove photo')),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Tag number',
                            controller: _tag,
                            icon: PhosphorIconsRegular.tag,
                            textCapitalization: TextCapitalization.characters,
                            validator: (v) => V.required(v, 'Tag'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Name',
                            controller: _name,
                            hint: 'e.g. Neema',
                            optional: true,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SelectField<PigStage>(
                      label: 'Stage',
                      value: _stage,
                      icon: PhosphorIconsRegular.chartLineUp,
                      options: [for (final s in PigStage.values) PickerOption(s, s.label, subtitle: s.hint)],
                      onChanged: _onStage,
                    ),
                    const SizedBox(height: 18),
                    ChoicePills<Sex>(
                      label: 'Sex',
                      value: _sex,
                      onChanged: (s) => setState(() => _sex = s),
                      options: [
                        for (final s in Sex.values) PickerOption(s, s.label, icon: s.icon, color: s == Sex.female ? AppColors.pinkDeep : AppColors.info),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SelectField<String>(
                      label: 'Breed',
                      value: _breed,
                      icon: PhosphorIconsRegular.dna,
                      options: [for (final b in pigBreeds) PickerOption(b, b)],
                      onChanged: (b) => setState(() => _breed = b),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DateField(
                            label: 'Birth date',
                            value: _birth,
                            optional: true,
                            lastDate: DateTime.now(),
                            onChanged: (d) => setState(() => _birth = d),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(label: 'Pen', controller: _pen, hint: 'e.g. Pen 2', optional: true, icon: PhosphorIconsRegular.squaresFour),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ChoicePills<bool>(
                      label: 'Where did it come from?',
                      value: _purchased,
                      onChanged: (v) => setState(() => _purchased = v),
                      options: const [
                        PickerOption(false, 'Born on farm', icon: PhosphorIconsBold.house),
                        PickerOption(true, 'Bought', icon: PhosphorIconsBold.shoppingCart),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DateField(
                            label: _purchased ? 'Date bought' : 'Date added',
                            value: _acquired,
                            lastDate: DateTime.now(),
                            onChanged: (d) => setState(() => _acquired = d ?? DateTime.now()),
                          ),
                        ),
                        if (_purchased) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              label: 'Price paid',
                              controller: _price,
                              optional: true,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: AppTextField.decimal,
                              validator: (v) => V.number(v, field: 'Price', optional: true, allowZero: true, max: 10000000),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_purchased && !_editing)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 6),
                        child: Text('The price is added to your expenses automatically.', style: context.text.bodySmall),
                      ),
                    if (!_editing) ...[
                      const SizedBox(height: 18),
                      AppTextField(
                        label: 'Current weight',
                        controller: _weight,
                        optional: true,
                        suffixText: 'kg',
                        icon: PhosphorIconsRegular.scales,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: AppTextField.decimal,
                        validator: (v) => V.number(v, field: 'Weight', optional: true, max: 450),
                      ),
                    ],
                    if (sows.isNotEmpty || boars.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SelectField<String?>(
                              label: 'Mother',
                              optional: true,
                              value: _motherId,
                              icon: PhosphorIconsRegular.genderFemale,
                              options: [
                                const PickerOption(null, 'Unknown'),
                                for (final s in sows) PickerOption(s.id, s.displayName, subtitle: s.tag),
                              ],
                              onChanged: (v) => setState(() => _motherId = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SelectField<String?>(
                              label: 'Father',
                              optional: true,
                              value: _fatherId,
                              icon: PhosphorIconsRegular.genderMale,
                              options: [
                                const PickerOption(null, 'Unknown'),
                                for (final b in boars) PickerOption(b.id, b.displayName, subtitle: b.tag),
                              ],
                              onChanged: (v) => setState(() => _fatherId = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    AppTextField(label: 'Notes', controller: _notes, optional: true, maxLines: 3, hint: 'Temperament, markings, anything useful'),
                    const SizedBox(height: 28),
                    PrimaryButton(label: _editing ? 'Save changes' : 'Add pig', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
