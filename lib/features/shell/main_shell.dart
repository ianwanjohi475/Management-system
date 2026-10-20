import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/phosphor.dart';
import '../../widgets/widgets.dart';
import '../animals/animals_screen.dart';
import '../home/home_screen.dart';
import '../reports/reports_screen.dart';
import '../sales/sales_screen.dart';
import 'quick_add_sheet.dart';

/// Lets screens inside the shell switch tabs (e.g. "See all sales").
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.switchTab, required super.child});
  final void Function(int index, {int? subTab}) switchTab;

  static ShellScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _animalsTab = ValueNotifier<int>(0);
  DateTime? _lastBack;

  late final _pages = [const HomeScreen(), AnimalsScreen(tab: _animalsTab), const SalesScreen(), const ReportsScreen()];

  void _switch(int i, {int? subTab}) {
    if (subTab != null) _animalsTab.value = subTab;
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  void dispose() {
    _animalsTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index != 0) {
          _switch(0);
          return;
        }
        final now = DateTime.now();
        if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBack = now;
          showToast('Press back again to exit', type: ToastType.info);
        }
      },
      child: ShellScope(
        switchTab: _switch,
        child: Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              for (var i = 0; i < _pages.length; i++)
                IgnorePointer(
                  ignoring: i != _index,
                  child: AnimatedOpacity(
                    opacity: i == _index ? 1 : 0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    child: TickerMode(enabled: i == _index, child: _pages[i]),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: _BottomBar(index: _index, onTap: _switch, onAdd: () => showQuickAdd(context)),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTap, required this.onAdd});

  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  static const _items = [
    (PhosphorIconsRegular.house, PhosphorIconsFill.house, 'Home'),
    (PhosphorIconsRegular.pawPrint, PhosphorIconsFill.pawPrint, 'Animals'),
    (PhosphorIconsRegular.receipt, PhosphorIconsFill.receipt, 'Sales'),
    (PhosphorIconsRegular.chartPieSlice, PhosphorIconsFill.chartPieSlice, 'Reports'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget item(int i) {
      final (icon, active, label) = _items[i];
      final sel = i == index;
      final color = sel ? Theme.of(context).colorScheme.primary : p.inkMuted;
      return Expanded(
        child: Semantics(
          button: true,
          selected: sel,
          label: label,
          excludeSemantics: true,
          child: Pressable(
            onTap: () => onTap(i),
            scale: 0.9,
            child: SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(horizontal: sel ? 16 : 0, vertical: 4),
                    decoration: BoxDecoration(color: sel ? p.brandTint : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Icon(sel ? active : icon, key: ValueKey(sel), color: color, size: 23),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: color),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 8, left: 8, right: 8, top: 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: p.shadow.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, -6))],
      ),
      child: SizedBox(
        height: 66,
        child: Row(
          children: [
            item(0),
            item(1),
            SizedBox(
              width: 72,
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Quick add',
                  excludeSemantics: true,
                  child: Pressable(
                    onTap: onAdd,
                    scale: 0.88,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: AppColors.forest.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: const Icon(PhosphorIconsBold.plus, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ),
            ),
            item(2),
            item(3),
          ],
        ),
      ),
    );
  }
}
