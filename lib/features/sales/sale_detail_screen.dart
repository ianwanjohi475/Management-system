import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../state/farm_store.dart';
import '../../widgets/widgets.dart';
import '../customers/customer_detail_screen.dart';
import '../system/not_found_screen.dart';
import 'receipt_pdf.dart';

class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({super.key, required this.saleId});
  final String saleId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FarmStore>();
    final s = store.sale(saleId);
    if (s == null) return const NotFoundScreen(message: 'This sale was deleted.');
    final flock = store.flock(s.flockId);
    final pigs = s.pigIds.map(store.pig).whereType<Pig>().toList();
    final farm = store.farm;

    Future<void> pdf({required bool print}) => guard(() async {
      final bytes = await buildReceipt(s, farm, flockName: flock?.name, pigTags: pigs.map((p) => p.tag).toList());
      print ? await printPdf(bytes, s.receiptLabel) : await sharePdf(bytes, '${s.receiptLabel}.pdf');
    }, haptic: false);

    final reminder =
        'Hello ${s.customerName}, this is ${farm?.name ?? 'your farm'}. '
        'A friendly reminder of ${Fmt.money(s.balance)} for ${s.quantityLabel} of ${s.product.label.toLowerCase()} on ${Fmt.date(s.date)} (${s.receiptLabel}). Thank you!';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: s.receiptLabel,
              subtitle: Fmt.dateTime(s.date),
              actions: [
                CircleIconButton(icon: PhosphorIconsBold.shareNetwork, tooltip: 'Share receipt', onTap: () => pdf(print: false)),
                CircleIconButton(
                  icon: PhosphorIconsBold.dotsThreeVertical,
                  tooltip: 'More',
                  onTap: () async {
                    final a = await showOptionsSheet<String>(
                      context,
                      title: s.receiptLabel,
                      options: const [
                        PickerOption('print', 'Print receipt', icon: PhosphorIconsBold.printer),
                        PickerOption('delete', 'Delete sale', subtitle: 'Animals return to stock', icon: PhosphorIconsBold.trash, color: AppColors.danger),
                      ],
                    );
                    if (a == 'print') {
                      await pdf(print: true);
                      return;
                    }
                    if (a != 'delete' || !context.mounted) return;
                    if (await confirm(
                      context,
                      title: 'Delete this sale?',
                      message: s.pigIds.isNotEmpty ? 'The pigs will be put back in your herd as active.' : 'Stock (eggs/birds) will be returned automatically.',
                    )) {
                      final ok = await guard(() => store.deleteSale(s.id), success: 'Sale deleted');
                      if (ok && context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _Receipt(sale: s, flockName: flock?.name, pigs: pigs, farm: farm).enter(0),
                  if (s.balance > 0) ...[
                    const SizedBox(height: 16),
                    PrimaryButton(label: 'Record payment', icon: PhosphorIconsBold.handCoins, onPressed: () => showPaymentSheet(context, s)).enter(1),
                  ],
                  if (s.customerPhone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ContactBtn(icon: PhosphorIconsBold.phone, label: 'Call', onTap: () => guard(() => callPhone(s.customerPhone), haptic: false)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ContactBtn(
                            icon: PhosphorIconsBold.chatText,
                            label: s.balance > 0 ? 'SMS reminder' : 'SMS',
                            onTap: () => guard(() => sendSms(s.customerPhone, s.balance > 0 ? reminder : ''), haptic: false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ContactBtn(
                            icon: PhosphorIconsBold.whatsappLogo,
                            label: 'WhatsApp',
                            onTap: () => guard(() => sendWhatsApp(s.customerPhone, s.balance > 0 ? reminder : 'Hello ${s.customerName}'), haptic: false),
                          ),
                        ),
                      ],
                    ).enter(2),
                  ],
                  if (s.customerId != null && store.customer(s.customerId) != null) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      onTap: () => go(context, CustomerDetailScreen(customerId: s.customerId!)),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Avatar(initials: store.customer(s.customerId)!.initials, size: 42),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.customerName, style: context.text.titleMedium),
                                Text('Owes ${Fmt.money(store.balanceOf(s.customerId!))} in total', style: context.text.bodySmall),
                              ],
                            ),
                          ),
                          const Icon(PhosphorIconsBold.caretRight, size: 16),
                        ],
                      ),
                    ).enter(3),
                  ],
                  if (s.payments.isNotEmpty) ...[
                    const SectionHeader('Payments', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          for (final (i, p) in s.payments.indexed) ...[
                            if (i > 0) const Divider(),
                            RecordTile(
                              icon: p.method.icon,
                              color: AppColors.success,
                              title: Fmt.money(p.amount),
                              subtitle: '${p.method.label} · ${Fmt.date(p.date)}${p.reference.isNotEmpty ? ' · ${p.reference}' : ''}',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (s.notes.isNotEmpty) ...[
                    const SectionHeader('Notes', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
                    AppCard(child: Text(s.notes, style: context.text.bodyLarge)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.sale, required this.flockName, required this.pigs, required this.farm});
  final Sale sale;
  final String? flockName;
  final List<Pig> pigs;
  final FarmProfile? farm;

  @override
  Widget build(BuildContext context) {
    final s = sale;
    return ClipPath(
      clipper: _ZigZag(),
      child: Container(
        color: context.palette.card,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: s.product.color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Image.asset(s.product.image),
            ),
            const SizedBox(height: 12),
            Text(Fmt.money(s.total), style: context.text.displaySmall),
            const SizedBox(height: 6),
            StatusPill(s.paymentStatus.label, color: s.paymentStatus.color, icon: s.balance > 0 ? PhosphorIconsBold.clock : PhosphorIconsBold.checkCircle),
            const SizedBox(height: 18),
            const _Dashes(),
            const SizedBox(height: 8),
            InfoRow(label: 'Product', value: s.product.label),
            InfoRow(label: 'Quantity', value: s.quantityLabel),
            InfoRow(label: 'Unit price', value: Fmt.money(s.unitPrice)),
            if (flockName != null) InfoRow(label: 'From flock', value: flockName!),
            if (pigs.isNotEmpty) InfoRow(label: 'Pigs', value: pigs.map((p) => p.tag).join(', ')),
            if (s.weightKg != null) InfoRow(label: 'Live weight', value: Fmt.kg(s.weightKg!)),
            InfoRow(label: 'Buyer', value: s.customerName.isEmpty ? 'Walk-in' : s.customerName),
            const SizedBox(height: 8),
            const _Dashes(),
            const SizedBox(height: 8),
            InfoRow(label: 'Total', value: Fmt.money(s.total), bold: true),
            InfoRow(label: 'Paid', value: Fmt.money(s.paid), valueColor: AppColors.success),
            InfoRow(label: 'Balance', value: Fmt.money(s.balance), bold: true, valueColor: s.balance > 0 ? AppColors.danger : null),
            const SizedBox(height: 10),
            Text(farm?.name ?? '', style: context.text.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _Dashes extends StatelessWidget {
  const _Dashes();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) => Row(
      children: List.generate(
        (c.maxWidth / 10).floor(),
        (_) => Expanded(
          child: Container(height: 1.2, margin: const EdgeInsets.symmetric(horizontal: 2), color: context.palette.border),
        ),
      ),
    ),
  );
}

class _ZigZag extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    const r = 18.0, tooth = 10.0;
    final p = Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(s.width - r, 0)
      ..quadraticBezierTo(s.width, 0, s.width, r)
      ..lineTo(s.width, s.height - tooth);
    final n = (s.width / (tooth * 2)).floor();
    final w = s.width / n;
    for (var i = n; i > 0; i--) {
      p.lineTo(w * i - w / 2, s.height);
      p.lineTo(w * (i - 1), s.height - tooth);
    }
    return p..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ContactBtn extends StatelessWidget {
  const _ContactBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(label, style: context.text.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

Future<void> showPaymentSheet(BuildContext context, Sale sale) => showFormSheet(
  context,
  title: 'Record payment',
  subtitle: '${Fmt.money(sale.balance)} is still owed on ${sale.receiptLabel}',
  child: _PaymentForm(sale: sale),
);

class _PaymentForm extends StatefulWidget {
  const _PaymentForm({required this.sale});
  final Sale sale;

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.sale.balance.toStringAsFixed(widget.sale.balance % 1 == 0 ? 0 : 2));
  final _ref = TextEditingController();
  PaymentMethod _method = PaymentMethod.mpesa;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final amt = V.parse(_amount.text)!.toDouble();
    final ok = await guard(
      () => context.read<FarmStore>().addPayment(widget.sale.id, Payment(date: _date, amount: amt, method: _method, reference: _ref.text.trim())),
      success: amt >= widget.sale.balance ? 'Fully paid. Nice!' : '${Fmt.money(amt)} received',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      children: [
        ChoicePills<PaymentMethod>(
          value: _method,
          onChanged: (m) => setState(() => _method = m),
          options: [for (final m in PaymentMethod.values.where((m) => m != PaymentMethod.credit)) PickerOption(m, m.label, icon: m.icon)],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Amount',
                controller: _amount,
                prefixText: '${Fmt.currency} ',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: AppTextField.decimal,
                validator: (v) => V.number(v, field: 'Amount', max: widget.sale.balance + 0.001),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DateField(label: 'Date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d ?? DateTime.now())),
            ),
          ],
        ),
        if (_method != PaymentMethod.cash) ...[
          const SizedBox(height: 16),
          AppTextField(
            label: _method == PaymentMethod.mpesa ? 'M-Pesa code' : 'Reference',
            controller: _ref,
            optional: true,
            textCapitalization: TextCapitalization.characters,
          ),
        ],
        const SizedBox(height: 24),
        PrimaryButton(label: 'Save payment', icon: PhosphorIconsBold.check, loading: _saving, onPressed: _save),
      ],
    ),
  );
}
