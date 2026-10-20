import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/phosphor.dart';
import '../core/utils/formatters.dart';
import 'buttons.dart';

/// Label sitting above the input, like the Foodie login.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional = false});
  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text,
            style: context.text.labelMedium?.copyWith(color: context.palette.ink),
          ),
          if (optional) TextSpan(text: '  optional', style: context.text.bodySmall),
        ],
      ),
    ),
  );
}

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.obscure = false,
    this.optional = false,
    this.maxLines = 1,
    this.suffixText,
    this.prefixText,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.sentences,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool obscure;
  final bool optional;
  final int maxLines;
  final String? suffixText;
  final String? prefixText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Numeric input that accepts decimals.
  static List<TextInputFormatter> get decimal => [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
  static List<TextInputFormatter> get digits => [FilteringTextInputFormatter.digitsOnly];

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      textInputAction: widget.maxLines > 1 ? TextInputAction.newline : widget.textInputAction,
      obscureText: _hidden,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      minLines: 1,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      textCapitalization: widget.textCapitalization,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: context.text.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20),
        suffixText: widget.suffixText,
        prefixText: widget.prefixText,
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(_hidden ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye, size: 20),
              )
            : null,
      ),
    );
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(widget.label!, optional: widget.optional),
        field,
      ],
    );
  }
}

/// Looks like a text field, opens a date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.optional = false,
    this.hint = 'Select date',
    this.helper,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool optional;
  final String hint;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      initialValue: value,
      validator: (_) => (!optional && value == null) ? '$label is required' : null,
      builder: (state) => PickerShell(
        label: label,
        optional: optional,
        icon: PhosphorIconsRegular.calendarBlank,
        text: value == null ? null : Fmt.date(value!),
        hint: hint,
        error: state.errorText,
        helper: helper,
        trailing: optional && value != null
            ? GestureDetector(onTap: () => onChanged(null), child: const Icon(PhosphorIconsRegular.x, size: 18))
            : const SizedBox.shrink(),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? (lastDate != null && lastDate!.isBefore(now) ? lastDate! : now),
            firstDate: firstDate ?? DateTime(now.year - 10),
            lastDate: lastDate ?? DateTime(now.year + 2),
          );
          if (picked != null) {
            onChanged(picked);
            state.didChange(picked);
          }
        },
      ),
    );
  }
}

/// The tappable box used by date and option pickers.
class PickerShell extends StatelessWidget {
  const PickerShell({
    super.key,
    this.label,
    required this.icon,
    this.text,
    required this.hint,
    required this.onTap,
    this.error,
    this.optional = false,
    this.trailing,
    this.leading,
    this.helper,
  });

  final String? label;
  final IconData icon;
  final String? text;
  final String hint;
  final VoidCallback onTap;
  final String? error;
  final bool optional;
  final Widget? trailing;
  final Widget? leading;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) FieldLabel(label!, optional: optional),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: context.isDark ? p.cardAlt : const Color(0xFFF5EFE8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: hasError ? AppColors.danger : Colors.transparent, width: 1.2),
              ),
              child: Row(
                children: [
                  leading ?? Icon(icon, size: 20, color: hasError ? AppColors.danger : p.inkMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text ?? hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text == null ? context.text.bodyMedium?.copyWith(color: p.inkMuted) : context.text.bodyLarge,
                    ),
                  ),
                  trailing ?? Icon(PhosphorIconsRegular.caretDown, size: 18, color: p.inkMuted),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              error!,
              style: context.text.bodySmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w500),
            ),
          )
        else if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(helper!, style: context.text.bodySmall),
          ),
      ],
    );
  }
}

class PickerOption<T> {
  const PickerOption(this.value, this.label, {this.subtitle, this.icon, this.color, this.image});
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final String? image;
}

/// Opens a searchable bottom sheet of options.
Future<T?> showOptionsSheet<T>(BuildContext context, {required String title, required List<PickerOption<T>> options, T? selected, bool searchable = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _OptionsSheet<T>(title: title, options: options, selected: selected, searchable: searchable || options.length > 8),
  );
}

class _OptionsSheet<T> extends StatefulWidget {
  const _OptionsSheet({required this.title, required this.options, this.selected, required this.searchable});
  final String title;
  final List<PickerOption<T>> options;
  final T? selected;
  final bool searchable;

  @override
  State<_OptionsSheet<T>> createState() => _OptionsSheetState<T>();
}

class _OptionsSheetState<T> extends State<_OptionsSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final list = widget.options.where((o) => _q.isEmpty || o.label.toLowerCase().contains(_q) || (o.subtitle?.toLowerCase().contains(_q) ?? false)).toList();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(widget.title, style: context.text.headlineSmall),
            ),
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                  decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 20)),
                ),
              ),
            Flexible(
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text('Nothing matches "$_q"', style: context.text.bodyMedium)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final o = list[i];
                        final sel = o.value == widget.selected;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Material(
                            color: sel ? p.brandTint : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              onTap: () => Navigator.pop(context, o.value),
                              leading: o.image != null
                                  ? Image.asset(o.image!, width: 40, height: 40)
                                  : o.icon != null
                                  ? Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: (o.color ?? AppColors.forest).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(o.icon, size: 20, color: o.color ?? AppColors.forest),
                                    )
                                  : null,
                              title: Text(o.label),
                              subtitle: o.subtitle == null ? null : Text(o.subtitle!),
                              trailing: sel ? Icon(PhosphorIconsFill.checkCircle, color: Theme.of(context).colorScheme.primary) : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form field that opens [showOptionsSheet].
class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon = PhosphorIconsRegular.listBullets,
    this.hint = 'Select',
    this.optional = false,
    this.sheetTitle,
    this.validator,
    this.helper,
  });

  final String label;
  final T? value;
  final List<PickerOption<T>> options;
  final ValueChanged<T> onChanged;
  final IconData icon;
  final String hint;
  final bool optional;
  final String? sheetTitle;
  final String? Function(T?)? validator;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    PickerOption<T>? current;
    for (final o in options) {
      if (o.value == value) current = o;
    }
    return FormField<T>(
      initialValue: value,
      validator: (_) => validator?.call(value) ?? ((!optional && value == null) ? 'Please choose ${label.toLowerCase()}' : null),
      builder: (state) => PickerShell(
        label: label,
        optional: optional,
        icon: current?.icon ?? icon,
        leading: current?.image != null ? Image.asset(current!.image!, width: 26, height: 26) : null,
        text: current?.label,
        hint: hint,
        error: state.errorText,
        helper: helper,
        onTap: () async {
          if (options.isEmpty) return;
          final v = await showOptionsSheet<T>(context, title: sheetTitle ?? label, options: options, selected: value);
          if (v != null) {
            onChanged(v);
            state.didChange(v);
          }
        },
      ),
    );
  }
}

/// Pill-shaped single choice (e.g. Male / Female, Trays / Pieces).
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({super.key, required this.options, required this.value, required this.onChanged, this.label, this.expand = true});

  final String? label;
  final List<PickerOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final pills = options.map((o) {
      final sel = o.value == value;
      final pill = Pressable(
        onTap: () => onChanged(o.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: sel ? scheme.primary : (context.isDark ? p.cardAlt : const Color(0xFFF5EFE8)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? scheme.primary : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (o.image != null) ...[
                Image.asset(o.image!, width: 24, height: 24),
                const SizedBox(width: 8),
              ] else if (o.icon != null) ...[
                Icon(o.icon, size: 18, color: sel ? scheme.onPrimary : (o.color ?? p.inkSoft)),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  o.label,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(fontSize: 13.5, color: sel ? scheme.onPrimary : p.inkSoft),
                ),
              ),
            ],
          ),
        ),
      );
      return expand ? Expanded(child: pill) : pill;
    }).toList();

    final row = expand
        ? Row(
            children: [
              for (var i = 0; i < pills.length; i++) ...[if (i > 0) const SizedBox(width: 8), pills[i]],
            ],
          )
        : Wrap(spacing: 8, runSpacing: 8, children: pills);

    if (label == null) return row;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [FieldLabel(label!), row]);
  }
}

/// +/- counter for small whole numbers.
class Stepper2 extends StatelessWidget {
  const Stepper2({super.key, required this.label, required this.value, required this.onChanged, this.min = 0, this.max = 99});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        Container(
          height: 56,
          decoration: BoxDecoration(color: context.isDark ? p.cardAlt : const Color(0xFFF5EFE8), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              IconButton(tooltip: 'Decrease', onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(PhosphorIconsBold.minus, size: 18)),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Text('$value', key: ValueKey(value), textAlign: TextAlign.center, style: context.text.titleLarge),
                ),
              ),
              IconButton(tooltip: 'Increase', onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(PhosphorIconsBold.plus, size: 18)),
            ],
          ),
        ),
      ],
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox({super.key, required this.hint, required this.onChanged, this.controller});
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        fillColor: p.card,
        prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
      ),
    );
  }
}
