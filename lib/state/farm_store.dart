import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';

import '../core/errors/app_exception.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/phosphor.dart';
import '../core/utils/formatters.dart';
import '../core/utils/ids.dart';
import '../data/models/models.dart';
import '../data/storage/local_db.dart';
import 'demo_data.dart';

enum AlertSeverity { info, warning, urgent }

enum AlertKind { farrowing, heatCheck, weaning, healthDue, lowStock, expiry, debt, task }

/// Something the farmer should look at, computed from their records.
class FarmAlert {
  FarmAlert({required this.id, required this.kind, required this.title, required this.subtitle, required this.date, required this.severity, this.targetId});

  final String id;
  final AlertKind kind;
  final String title;
  final String subtitle;
  final DateTime date;
  final AlertSeverity severity;
  final String? targetId;

  IconData get icon => switch (kind) {
    AlertKind.farrowing => PhosphorIconsBold.baby,
    AlertKind.heatCheck => PhosphorIconsBold.thermometerHot,
    AlertKind.weaning => PhosphorIconsBold.arrowsSplit,
    AlertKind.healthDue => PhosphorIconsBold.syringe,
    AlertKind.lowStock => PhosphorIconsBold.package,
    AlertKind.expiry => PhosphorIconsBold.hourglassLow,
    AlertKind.debt => PhosphorIconsBold.handCoins,
    AlertKind.task => PhosphorIconsBold.checkSquare,
  };

  Color get color => switch (severity) {
    AlertSeverity.urgent => AppColors.danger,
    AlertSeverity.warning => AppColors.warning,
    AlertSeverity.info => AppColors.info,
  };
}

/// Period used by reports and dashboards.
class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  static DateRange lastDays(int days) {
    final end = dateOnly(DateTime.now()).add(const Duration(days: 1));
    return DateRange(end.subtract(Duration(days: days)), end);
  }

  static DateRange thisMonth() {
    final n = DateTime.now();
    return DateRange(DateTime(n.year, n.month), DateTime(n.year, n.month + 1));
  }

  static DateRange thisYear() {
    final n = DateTime.now();
    return DateRange(DateTime(n.year), DateTime(n.year + 1));
  }

  static DateRange allTime() => DateRange(DateTime(2000), DateTime.now().add(const Duration(days: 1)));
}

/// All farm data for the logged-in farmer, plus every rule that keeps it consistent.
class FarmStore extends ChangeNotifier {
  String? _userId;
  bool _loading = false;
  bool get loading => _loading;
  bool get isOpen => _userId != null;

  late Box _meta;
  late Collection<Pig> _pigs;
  late Collection<WeightRecord> _weights;
  late Collection<BreedingRecord> _breedings;
  late Collection<Flock> _flocks;
  late Collection<EggRecord> _eggs;
  late Collection<MortalityRecord> _mortality;
  late Collection<HealthRecord> _health;
  late Collection<Sale> _sales;
  late Collection<Customer> _customers;
  late Collection<Expense> _expenses;
  late Collection<InventoryItem> _items;
  late Collection<StockMovement> _movements;
  late Collection<FarmTask> _tasks;

  FarmProfile? _farm;
  FarmProfile? get farm => _farm;
  bool get hasFarm => _farm != null;

  /// Records skipped on load because they were unreadable.
  int get corruptRecords => _all.fold(0, (s, c) => s + c.corrupt);

  List<Collection> get _all => [_pigs, _weights, _breedings, _flocks, _eggs, _mortality, _health, _sales, _customers, _expenses, _items, _movements, _tasks];

  Future<void> open(String userId) async {
    if (_userId == userId) return;
    _loading = true;
    final p = 'u_${userId.replaceAll('-', '').substring(0, 12)}_';
    _meta = await LocalDb.openRaw('${p}meta');
    final box = await LocalDb.open('${p}data');
    _pigs = Collection(box, 'pigs', Pig.fromJson);
    _weights = Collection(box, 'weights', WeightRecord.fromJson);
    _breedings = Collection(box, 'breedings', BreedingRecord.fromJson);
    _flocks = Collection(box, 'flocks', Flock.fromJson);
    _eggs = Collection(box, 'eggs', EggRecord.fromJson);
    _mortality = Collection(box, 'mortality', MortalityRecord.fromJson);
    _health = Collection(box, 'health', HealthRecord.fromJson);
    _sales = Collection(box, 'sales', Sale.fromJson);
    _customers = Collection(box, 'customers', Customer.fromJson);
    _expenses = Collection(box, 'expenses', Expense.fromJson);
    _items = Collection(box, 'items', InventoryItem.fromJson);
    _movements = Collection(box, 'movements', StockMovement.fromJson);
    _tasks = Collection(box, 'tasks', FarmTask.fromJson);
    final rawFarm = _meta.get('farm');
    _farm = null;
    if (rawFarm is String) {
      try {
        _farm = FarmProfile.fromJson(jsonDecode(rawFarm) as Map);
      } catch (_) {}
    }
    Fmt.currency = _farm?.currency ?? 'KES';
    _userId = userId;
    _loading = false;
    notifyListeners();
  }

  /// Re-reads computed values (pull-to-refresh).
  void refresh() => notifyListeners();

  void close() {
    _userId = null;
    _farm = null;
    notifyListeners();
  }

  Future<T> _write<T>(Future<T> Function() fn) async {
    if (!isOpen) throw const StorageException('Please log in again.');
    final r = await fn();
    notifyListeners();
    return r;
  }

  // ───────────────────────── Farm profile ─────────────────────────

  Future<void> saveFarm(FarmProfile f) => _write(() async {
    await _meta.put('farm', jsonEncode(f.toJson()));
    _farm = f;
    Fmt.currency = f.currency;
  });

  int get eggsPerTray => _farm?.eggsPerTray ?? 30;

  Set<String> get dismissedAlerts => (_meta.get('dismissed') as List?)?.map((e) => '$e').toSet() ?? {};

  Future<void> dismissAlert(String id) => _write(() async {
    await _meta.put('dismissed', [...dismissedAlerts, id]);
  });

  int _nextReceipt() {
    final n = (_meta.get('receiptSeq') as int? ?? 0) + 1;
    _meta.put('receiptSeq', n);
    return n;
  }

  // ───────────────────────── Pigs ─────────────────────────

  List<Pig> get pigs => _pigs.all..sort((a, b) => a.tag.compareTo(b.tag));
  List<Pig> get activePigs => pigs.where((p) => p.isActive).toList();
  Pig? pig(String? id) => _pigs.byId(id);
  List<Pig> get sows => activePigs.where((p) => p.sex == Sex.female && (p.stage == PigStage.sow || p.stage == PigStage.gilt)).toList();
  List<Pig> get boars => activePigs.where((p) => p.sex == Sex.male && p.stage == PigStage.boar).toList();

  Map<PigStage, int> get pigsByStage {
    final m = <PigStage, int>{};
    for (final p in activePigs) {
      m[p.stage] = (m[p.stage] ?? 0) + 1;
    }
    return m;
  }

  List<Pig> offspringOf(String pigId) => pigs.where((p) => p.motherId == pigId || p.fatherId == pigId).toList();

  String suggestPigTag() {
    var max = 0;
    for (final p in _pigs.all) {
      final n = int.tryParse(p.tag.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n > max) max = n;
    }
    return 'P-${(max + 1).toString().padLeft(3, '0')}';
  }

  void _checkTag(String tag, {String? exceptId}) {
    final t = tag.trim().toLowerCase();
    if (t.isEmpty) throw const ValidationException('Tag number is required.');
    final clash = _pigs.all.any((p) => p.id != exceptId && p.isActive && p.tag.trim().toLowerCase() == t);
    if (clash) throw ValidationException('Another active pig already has tag "$tag".');
  }

  Future<Pig> savePig(Pig pig, {double? initialWeight}) => _write(() async {
    _checkTag(pig.tag, exceptId: pig.id);
    if (pig.birthDate != null && pig.birthDate!.isAfter(DateTime.now())) {
      throw const ValidationException("Birth date can't be in the future.");
    }
    if (pig.stage == PigStage.sow || pig.stage == PigStage.gilt) {
      if (pig.sex != Sex.female) throw const ValidationException('Sows and gilts must be female.');
    }
    if (pig.stage == PigStage.boar && pig.sex != Sex.male) {
      throw const ValidationException('A boar must be male.');
    }
    final isNew = !_pigs.contains(pig.id);
    await _pigs.put(pig);
    if (initialWeight != null && initialWeight > 0) {
      await _weights.put(WeightRecord(id: newId(), pigId: pig.id, date: DateTime.now(), kg: initialWeight));
    }
    if (isNew && pig.purchased && (pig.purchasePrice ?? 0) > 0) {
      await _expenses.put(
        Expense(
          id: newId(),
          date: pig.acquiredDate,
          category: ExpenseCategory.stock,
          amount: pig.purchasePrice!,
          description: 'Bought pig ${pig.tag}',
          linkedId: pig.id,
        ),
      );
    }
    return pig;
  });

  Future<void> deletePig(String id) => _write(() async {
    await _weights.removeWhere((w) => w.pigId == id);
    await _breedings.removeWhere((b) => b.sowId == id);
    final health = _health.all.where((h) => h.targetType == TargetType.pig && h.targetId == id).toList();
    for (final h in health) {
      if (h.expenseId != null) await _expenses.remove(h.expenseId!);
    }
    await _health.removeWhere((h) => h.targetType == TargetType.pig && h.targetId == id);
    await _expenses.removeWhere((e) => e.linkedId == id);
    await _pigs.remove(id);
  });

  Future<void> markPigDead(String id, DateTime date, String cause) => _write(() async {
    final p = _pigs.byId(id);
    if (p == null) throw const NotFoundException('This pig no longer exists.');
    await _pigs.put(p.copyWith(status: PigStatus.dead, statusDate: date, statusNote: cause));
  });

  Future<void> restorePig(String id) => _write(() async {
    final p = _pigs.byId(id);
    if (p == null) return;
    _checkTag(p.tag, exceptId: p.id);
    await _pigs.put(Pig.fromJson({...p.toJson(), 'status': 'active', 'statusDate': null, 'statusNote': ''}));
  });

  // Weights
  List<WeightRecord> weightsOf(String pigId) => _weights.all.where((w) => w.pigId == pigId).toList()..sort((a, b) => a.date.compareTo(b.date));

  WeightRecord? latestWeight(String pigId) {
    final w = weightsOf(pigId);
    return w.isEmpty ? null : w.last;
  }

  /// Average daily gain (kg/day) between first and last weighing.
  double? dailyGain(String pigId) {
    final w = weightsOf(pigId);
    if (w.length < 2) return null;
    final days = w.last.date.difference(w.first.date).inDays;
    if (days <= 0) return null;
    return (w.last.kg - w.first.kg) / days;
  }

  Future<void> addWeight(String pigId, DateTime date, double kg, String notes) => _write(() async {
    if (kg <= 0 || kg > 450) throw const ValidationException('Enter a weight between 0.5 and 450 kg.');
    if (date.isAfter(DateTime.now())) throw const ValidationException("Date can't be in the future.");
    await _weights.put(WeightRecord(id: newId(), pigId: pigId, date: date, kg: kg, notes: notes));
  });

  Future<void> deleteWeight(String id) => _write(() => _weights.remove(id));

  // Breeding
  List<BreedingRecord> breedingsOf(String sowId) =>
      _breedings.all.where((b) => b.sowId == sowId).toList()..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));

  List<BreedingRecord> get breedings => _breedings.all..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
  List<BreedingRecord> get openBreedings => breedings.where((b) => b.status.isOpen).toList();
  List<BreedingRecord> get nursingLitters => breedings.where((b) => b.status == BreedingStatus.farrowed).toList();

  BreedingRecord? activeBreeding(String sowId) {
    for (final b in breedingsOf(sowId)) {
      if (b.status.isOpen || b.status == BreedingStatus.farrowed) return b;
    }
    return null;
  }

  Future<void> addBreeding(BreedingRecord b) => _write(() async {
    final sow = _pigs.byId(b.sowId);
    if (sow == null || !sow.isActive) throw const ValidationException('Choose an active sow or gilt.');
    if (sow.sex != Sex.female) throw const ValidationException('Only female pigs can be served.');
    if (b.serviceDate.isAfter(DateTime.now())) throw const ValidationException("Service date can't be in the future.");
    final open = activeBreeding(sow.id);
    if (open != null && open.id != b.id) {
      throw ValidationException('${sow.displayName} already has an open ${open.status.label.toLowerCase()} record. Close it first.');
    }
    await _breedings.put(b);
    if (sow.stage == PigStage.gilt && b.status == BreedingStatus.farrowed) {
      await _pigs.put(sow.copyWith(stage: PigStage.sow));
    }
  });

  Future<void> confirmPregnancy(String id) => _write(() async {
    final b = _breedings.byId(id);
    if (b == null) throw const NotFoundException('Breeding record not found.');
    await _breedings.put(b.copyWith(status: BreedingStatus.pregnant));
  });

  Future<void> markReturnedToHeat(String id) => _write(() async {
    final b = _breedings.byId(id);
    if (b == null) throw const NotFoundException('Breeding record not found.');
    await _breedings.put(b.copyWith(status: BreedingStatus.failed));
  });

  /// Records farrowing and optionally adds each live piglet to the herd.
  Future<int> recordFarrowing(
    String id, {
    required DateTime date,
    required int bornAlive,
    required int stillborn,
    required bool addPiglets,
    String breed = '',
  }) => _write(() async {
    final b = _breedings.byId(id);
    if (b == null) throw const NotFoundException('Breeding record not found.');
    if (date.isBefore(b.serviceDate)) throw const ValidationException("Farrowing can't be before the service date.");
    if (date.isAfter(DateTime.now())) throw const ValidationException("Date can't be in the future.");
    if (bornAlive < 0 || bornAlive > 30 || stillborn < 0 || stillborn > 30) {
      throw const ValidationException('Litter size looks wrong. Check the numbers.');
    }
    await _breedings.put(b.copyWith(status: BreedingStatus.farrowed, farrowDate: date, bornAlive: bornAlive, stillborn: stillborn));
    final sow = _pigs.byId(b.sowId);
    if (sow != null && sow.stage == PigStage.gilt) await _pigs.put(sow.copyWith(stage: PigStage.sow));
    var added = 0;
    if (addPiglets && sow != null) {
      final now = DateTime.now();
      final piglets = <Pig>[];
      for (var i = 1; i <= bornAlive; i++) {
        var tag = '${sow.tag}-${Fmt.dateShort(date).replaceAll(' ', '')}-$i';
        while (_pigs.all.any((p) => p.tag == tag)) {
          tag = '$tag*';
        }
        piglets.add(
          Pig(
            id: newId(),
            tag: tag,
            sex: i.isEven ? Sex.male : Sex.female,
            breed: breed.isEmpty ? sow.breed : breed,
            stage: PigStage.piglet,
            birthDate: date,
            acquiredDate: date,
            motherId: sow.id,
            fatherId: b.boarId,
            pen: sow.pen,
            notes: 'Born on farm. Check and correct sex.',
            createdAt: now,
          ),
        );
      }
      await _pigs.putAll(piglets);
      added = piglets.length;
    }
    return added;
  });

  Future<void> recordWeaning(String id, DateTime date, int weaned) => _write(() async {
    final b = _breedings.byId(id);
    if (b == null) throw const NotFoundException('Breeding record not found.');
    if (b.farrowDate != null && date.isBefore(b.farrowDate!)) throw const ValidationException("Weaning can't be before farrowing.");
    if (weaned < 0 || weaned > (b.bornAlive ?? 30)) throw ValidationException('Weaned must be between 0 and ${b.bornAlive ?? 30}.');
    await _breedings.put(b.copyWith(status: BreedingStatus.weaned, weanDate: date, weanedCount: weaned));
    // Piglets from this litter become weaners.
    for (final p in _pigs.all.where(
      (p) =>
          p.motherId == b.sowId &&
          p.isActive &&
          p.stage == PigStage.piglet &&
          p.birthDate != null &&
          b.farrowDate != null &&
          p.birthDate!.isSameDay(b.farrowDate!),
    )) {
      await _pigs.put(p.copyWith(stage: PigStage.weaner));
    }
  });

  Future<void> deleteBreeding(String id) => _write(() => _breedings.remove(id));

  // ───────────────────────── Poultry ─────────────────────────

  List<Flock> get flocks => _flocks.all..sort((a, b) => b.startDate.compareTo(a.startDate));
  List<Flock> get activeFlocks => flocks.where((f) => f.isActive).toList();
  Flock? flock(String? id) => _flocks.byId(id);

  int deathsIn(String flockId) => _mortality.all.where((m) => m.flockId == flockId).fold(0, (s, m) => s + m.count);
  int birdsSoldFrom(String flockId) => _sales.all.where((s) => s.flockId == flockId && s.product.fromFlock).fold(0, (s, x) => s + x.quantity.round());

  int birdsAlive(String flockId) {
    final f = _flocks.byId(flockId);
    if (f == null) return 0;
    return (f.initialCount - deathsIn(flockId) - birdsSoldFrom(flockId)).clamp(0, f.initialCount);
  }

  int get totalBirds => activeFlocks.fold(0, (s, f) => s + birdsAlive(f.id));
  int birdsOfType(BirdType t) => activeFlocks.where((f) => f.type == t).fold(0, (s, f) => s + birdsAlive(f.id));

  double mortalityRate(String flockId) {
    final f = _flocks.byId(flockId);
    if (f == null || f.initialCount == 0) return 0;
    return deathsIn(flockId) / f.initialCount * 100;
  }

  Future<Flock> saveFlock(Flock f) => _write(() async {
    if (f.name.trim().isEmpty) throw const ValidationException('Give the flock a name.');
    if (f.initialCount <= 0) throw const ValidationException('Number of birds must be more than 0.');
    if (f.startDate.isAfter(DateTime.now())) throw const ValidationException("Start date can't be in the future.");
    final isNew = !_flocks.contains(f.id);
    if (!isNew) {
      final used = deathsIn(f.id) + birdsSoldFrom(f.id);
      if (f.initialCount < used) {
        throw ValidationException('This flock already has $used birds dead or sold. Starting count must be at least $used.');
      }
    }
    if (_flocks.all.any((x) => x.id != f.id && x.isActive && x.name.trim().toLowerCase() == f.name.trim().toLowerCase())) {
      throw ValidationException('You already have an active flock called "${f.name}".');
    }
    await _flocks.put(f);
    if (isNew && (f.costPerBird ?? 0) > 0) {
      await _expenses.put(
        Expense(
          id: newId(),
          date: f.startDate,
          category: ExpenseCategory.stock,
          amount: f.costPerBird! * f.initialCount,
          description: 'Bought ${f.initialCount} ${f.type.label.toLowerCase()} – ${f.name}',
          linkedId: f.id,
        ),
      );
    }
    return f;
  });

  Future<void> closeFlock(String id) => _write(() async {
    final f = _flocks.byId(id);
    if (f == null) return;
    await _flocks.put(f.copyWith(status: f.isActive ? FlockStatus.closed : FlockStatus.active));
  });

  Future<void> deleteFlock(String id) => _write(() async {
    if (_sales.all.any((s) => s.flockId == id)) {
      throw const ValidationException('This flock has sales recorded. Close it instead of deleting, so your sales history stays correct.');
    }
    await _eggs.removeWhere((e) => e.flockId == id);
    await _mortality.removeWhere((m) => m.flockId == id);
    final health = _health.all.where((h) => h.targetType == TargetType.flock && h.targetId == id).toList();
    for (final h in health) {
      if (h.expenseId != null) await _expenses.remove(h.expenseId!);
    }
    await _health.removeWhere((h) => h.targetType == TargetType.flock && h.targetId == id);
    await _expenses.removeWhere((e) => e.linkedId == id);
    await _flocks.remove(id);
  });

  // Eggs
  List<EggRecord> get eggRecords => _eggs.all..sort((a, b) => b.date.compareTo(a.date));
  List<EggRecord> eggsOf(String flockId) => eggRecords.where((e) => e.flockId == flockId).toList();

  int eggsOnDay(DateTime day, {String? flockId}) =>
      _eggs.all.where((e) => e.date.isSameDay(day) && (flockId == null || e.flockId == flockId)).fold(0, (s, e) => s + e.good);

  int eggsInRange(DateRange r) => _eggs.all.where((e) => r.contains(e.date)).fold(0, (s, e) => s + e.good);
  int brokenInRange(DateRange r) => _eggs.all.where((e) => r.contains(e.date)).fold(0, (s, e) => s + e.broken);

  /// Good eggs collected minus eggs sold.
  int get eggStock {
    final collected = _eggs.all.fold(0, (s, e) => s + e.good);
    final sold = _sales.all.fold(0, (s, x) => s + x.eggsCount(eggsPerTray));
    return collected - sold < 0 ? 0 : collected - sold;
  }

  /// Hen-day lay rate for a flock over the last 7 days.
  double layRate(String flockId) {
    final alive = birdsAlive(flockId);
    if (alive == 0) return 0;
    final r = DateRange.lastDays(7);
    final days = _eggs.all.where((e) => e.flockId == flockId && r.contains(e.date)).map((e) => dateOnly(e.date)).toSet().length;
    if (days == 0) return 0;
    final eggs = _eggs.all.where((e) => e.flockId == flockId && r.contains(e.date)).fold(0, (s, e) => s + e.collected);
    return (eggs / (alive * days) * 100).clamp(0, 100).toDouble();
  }

  Future<void> saveEggs(EggRecord e) => _write(() async {
    final f = _flocks.byId(e.flockId);
    if (f == null) throw const ValidationException('Choose a flock.');
    if (!f.type.laysEggs) throw const ValidationException("Broilers don't lay eggs. Pick a layer or kienyeji flock.");
    if (e.date.isAfter(DateTime.now())) throw const ValidationException("Date can't be in the future.");
    if (e.collected <= 0) throw const ValidationException('Enter how many eggs were collected.');
    if (e.broken > e.collected) throw const ValidationException("Broken eggs can't be more than collected.");
    final alive = birdsAlive(f.id);
    if (e.collected > alive * 1.1 + 5) {
      throw ValidationException('${f.name} has $alive birds. ${e.collected} eggs in one day looks too high.');
    }
    final dup = _eggs.all.where((x) => x.id != e.id && x.flockId == e.flockId && x.date.isSameDay(e.date));
    if (dup.isNotEmpty) {
      throw ValidationException('Eggs for ${f.name} on ${Fmt.dateShort(e.date)} are already recorded. Edit that entry instead.');
    }
    // Editing must not push stock below what is already sold.
    final old = _eggs.byId(e.id);
    final delta = e.good - (old?.good ?? 0);
    if (eggStock + delta < 0) {
      throw const ValidationException('Some of these eggs are already sold. The new count would leave stock below zero.');
    }
    await _eggs.put(e);
  });

  Future<void> deleteEggs(String id) => _write(() async {
    final e = _eggs.byId(id);
    if (e == null) return;
    if (eggStock - e.good < 0) {
      throw const ValidationException('These eggs are already counted in sales. Delete those sales first.');
    }
    await _eggs.remove(id);
  });

  // Mortality
  List<MortalityRecord> mortalityOf(String flockId) => _mortality.all.where((m) => m.flockId == flockId).toList()..sort((a, b) => b.date.compareTo(a.date));

  int deathsInRange(DateRange r) => _mortality.all.where((m) => r.contains(m.date)).fold(0, (s, m) => s + m.count);

  Future<void> addMortality(MortalityRecord m) => _write(() async {
    final alive = birdsAlive(m.flockId);
    if (m.count <= 0) throw const ValidationException('Enter how many birds died.');
    if (m.count > alive) throw ValidationException('Only $alive birds are left in this flock.');
    if (m.date.isAfter(DateTime.now())) throw const ValidationException("Date can't be in the future.");
    await _mortality.put(m);
  });

  Future<void> deleteMortality(String id) => _write(() => _mortality.remove(id));

  // ───────────────────────── Health ─────────────────────────

  List<HealthRecord> get healthRecords => _health.all..sort((a, b) => b.date.compareTo(a.date));
  List<HealthRecord> healthOf(TargetType t, String id) => healthRecords.where((h) => h.targetType == t && h.targetId == id).toList();

  String targetName(TargetType t, String id) =>
      t == TargetType.pig ? (_pigs.byId(id)?.displayName ?? 'Removed pig') : (_flocks.byId(id)?.name ?? 'Removed flock');

  Future<void> addHealth(HealthRecord h) => _write(() async {
    if (h.product.trim().isEmpty) throw const ValidationException('Enter the medicine or vaccine name.');
    if (h.date.isAfter(DateTime.now())) throw const ValidationException("Date can't be in the future.");
    if (h.nextDue != null && !h.nextDue!.isAfter(h.date)) {
      throw const ValidationException('Next due date must be after the treatment date.');
    }
    var rec = h;
    if (h.cost > 0) {
      final ex = Expense(
        id: newId(),
        date: h.date,
        category: ExpenseCategory.vet,
        amount: h.cost,
        description: '${h.type.label}: ${h.product} – ${targetName(h.targetType, h.targetId)}',
        linkedId: h.id,
      );
      await _expenses.put(ex);
      rec = h.copyWith(expenseId: ex.id);
    }
    // A new record for the same thing closes the earlier reminder.
    for (final old in _health.all.where(
      (o) => o.hasOpenFollowUp && o.targetId == h.targetId && o.type == h.type && o.product.toLowerCase() == h.product.toLowerCase(),
    )) {
      await _health.put(old.copyWith(nextDoneAt: h.date));
    }
    await _health.put(rec);
  });

  Future<void> completeFollowUp(String id) => _write(() async {
    final h = _health.byId(id);
    if (h != null) await _health.put(h.copyWith(nextDoneAt: DateTime.now()));
  });

  Future<void> deleteHealth(String id) => _write(() async {
    final h = _health.byId(id);
    if (h?.expenseId != null) await _expenses.remove(h!.expenseId!);
    await _health.remove(id);
  });

  // ───────────────────────── Customers ─────────────────────────

  List<Customer> get customers => _customers.all..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  Customer? customer(String? id) => _customers.byId(id);

  List<Sale> salesOf(String customerId) => sales.where((s) => s.customerId == customerId).toList();
  double balanceOf(String customerId) => salesOf(customerId).fold(0, (s, x) => s + x.balance);
  double spentBy(String customerId) => salesOf(customerId).fold(0, (s, x) => s + x.total);

  Future<Customer> saveCustomer(Customer c) => _write(() async {
    if (c.name.trim().length < 2) throw const ValidationException('Enter the customer name.');
    await _customers.put(c);
    // Keep the name on existing receipts in sync.
    for (final s in _sales.all.where((s) => s.customerId == c.id)) {
      await _sales.put(s.copyWith(customerName: c.name, customerPhone: c.phone));
    }
    return c;
  });

  Future<void> deleteCustomer(String id) => _write(() async {
    if (balanceOf(id) > 0) throw const ValidationException('This customer still owes you money. Clear the balance first.');
    await _customers.remove(id);
  });

  Customer? _matchCustomer(String name, String phone) {
    final n = name.trim().toLowerCase();
    final ph = phone.replaceAll(RegExp(r'\D'), '');
    for (final c in _customers.all) {
      final cp = c.phone.replaceAll(RegExp(r'\D'), '');
      if (ph.length >= 9 && cp.length >= 9 && cp.endsWith(ph.substring(ph.length - 9))) return c;
      if (ph.isEmpty && c.name.trim().toLowerCase() == n) return c;
    }
    return null;
  }

  // ───────────────────────── Sales ─────────────────────────

  List<Sale> get sales => _sales.all..sort((a, b) => b.date.compareTo(a.date) != 0 ? b.date.compareTo(a.date) : b.receiptNo.compareTo(a.receiptNo));
  Sale? sale(String? id) => _sales.byId(id);
  List<Sale> salesIn(DateRange r) => sales.where((s) => r.contains(s.date)).toList();
  double revenueIn(DateRange r) => salesIn(r).fold(0, (s, x) => s + x.total);
  double collectedIn(DateRange r) => salesIn(r).fold(0, (s, x) => s + x.paid);
  List<Sale> get unpaidSales => sales.where((s) => s.balance > 0).toList();
  double get totalOwed => unpaidSales.fold(0, (s, x) => s + x.balance);

  Map<Product, double> revenueByProduct(DateRange r) {
    final m = <Product, double>{};
    for (final s in salesIn(r)) {
      m[s.product] = (m[s.product] ?? 0) + s.total;
    }
    return m;
  }

  /// Saves a new sale after checking stock, and links / creates the customer.
  Future<Sale> createSale({
    required DateTime date,
    required Product product,
    required double quantity,
    required double unitPrice,
    EggUnit eggUnit = EggUnit.tray,
    String? flockId,
    List<String> pigIds = const [],
    double? weightKg,
    String customerName = '',
    String customerPhone = '',
    String? customerId,
    double amountPaid = 0,
    PaymentMethod method = PaymentMethod.cash,
    String reference = '',
    String notes = '',
  }) => _write(() async {
    if (quantity <= 0) throw const ValidationException('Quantity must be more than 0.');
    if (unitPrice < 0) throw const ValidationException("Price can't be negative.");
    if (date.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw const ValidationException("Sale date can't be in the future.");
    }
    final total = quantity * unitPrice;
    if (amountPaid > total + 0.001) throw ValidationException('Amount paid is more than the total (${Fmt.money(total)}).');

    switch (product) {
      case Product.eggs:
        final eggs = (quantity * (eggUnit == EggUnit.tray ? eggsPerTray : 1)).round();
        if (eggUnit == EggUnit.piece && quantity % 1 != 0) throw const ValidationException('Egg pieces must be a whole number.');
        if (eggs > eggStock) {
          final trays = eggStock ~/ eggsPerTray, left = eggStock % eggsPerTray;
          throw ValidationException(
            'Not enough eggs in stock. You have $eggStock eggs ($trays trays${left > 0 ? ' + $left' : ''}). Record today\'s collection first.',
          );
        }
      case Product.liveChicken:
      case Product.dressedChicken:
        if (flockId == null) throw const ValidationException('Choose which flock the birds came from.');
        if (quantity % 1 != 0) throw const ValidationException('Number of birds must be a whole number.');
        final alive = birdsAlive(flockId);
        if (quantity > alive) throw ValidationException('That flock only has $alive birds left.');
      case Product.pig:
      case Product.piglet:
        if (pigIds.isEmpty) throw const ValidationException('Select the pigs you sold.');
        for (final id in pigIds) {
          final p = _pigs.byId(id);
          if (p == null || !p.isActive) throw const ValidationException('One of the selected pigs is no longer active.');
        }
        if (pigIds.length != quantity.round()) throw const ValidationException('Quantity must match the number of pigs selected.');
      case Product.manure:
        break;
    }

    String? custId = customerId;
    var name = customerName.trim();
    var phone = customerPhone.trim();
    if (custId == null && name.isNotEmpty) {
      final existing = _matchCustomer(name, phone);
      if (existing != null) {
        custId = existing.id;
      } else {
        final c = Customer(id: newId(), name: name, phone: phone, createdAt: DateTime.now());
        await _customers.put(c);
        custId = c.id;
      }
    }
    if (custId != null) {
      final c = _customers.byId(custId);
      if (c != null) {
        name = c.name;
        phone = c.phone;
      }
    }
    if (amountPaid < total && custId == null) {
      throw const ValidationException('Add the buyer\'s name so you can track what they owe.');
    }

    final sale = Sale(
      id: newId(),
      receiptNo: _nextReceipt(),
      date: date,
      product: product,
      quantity: quantity,
      unitPrice: unitPrice,
      eggUnit: eggUnit,
      customerId: custId,
      customerName: name,
      customerPhone: phone,
      payments: amountPaid > 0
          ? [Payment(date: date, amount: amountPaid, method: method == PaymentMethod.credit ? PaymentMethod.cash : method, reference: reference)]
          : const [],
      flockId: product.fromFlock ? flockId : null,
      pigIds: product.fromPigs ? pigIds : const [],
      weightKg: weightKg,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await _sales.put(sale);
    for (final id in sale.pigIds) {
      final p = _pigs.byId(id)!;
      await _pigs.put(p.copyWith(status: PigStatus.sold, statusDate: date, statusNote: 'Receipt ${sale.receiptLabel}'));
    }
    return sale;
  });

  Future<void> addPayment(String saleId, Payment p) => _write(() async {
    final s = _sales.byId(saleId);
    if (s == null) throw const NotFoundException('This sale no longer exists.');
    if (p.amount <= 0) throw const ValidationException('Enter an amount.');
    if (p.amount > s.balance + 0.001) throw ValidationException('Only ${Fmt.money(s.balance)} is owed on this sale.');
    await _sales.put(s.copyWith(payments: [...s.payments, p]));
  });

  /// Deleting a sale puts pigs back in the herd; birds and eggs come back automatically.
  Future<void> deleteSale(String id) => _write(() async {
    final s = _sales.byId(id);
    if (s == null) return;
    for (final pid in s.pigIds) {
      final p = _pigs.byId(pid);
      if (p != null && p.status == PigStatus.sold) {
        await _pigs.put(Pig.fromJson({...p.toJson(), 'status': 'active', 'statusDate': null, 'statusNote': ''}));
      }
    }
    await _sales.remove(id);
  });

  // ───────────────────────── Expenses ─────────────────────────

  List<Expense> get expenses => _expenses.all..sort((a, b) => b.date.compareTo(a.date));
  List<Expense> expensesIn(DateRange r) => expenses.where((e) => r.contains(e.date)).toList();
  double expenseTotalIn(DateRange r) => expensesIn(r).fold(0, (s, e) => s + e.amount);

  Map<ExpenseCategory, double> expensesByCategory(DateRange r) {
    final m = <ExpenseCategory, double>{};
    for (final e in expensesIn(r)) {
      m[e.category] = (m[e.category] ?? 0) + e.amount;
    }
    return m;
  }

  Future<void> saveExpense(Expense e) => _write(() async {
    if (e.amount <= 0) throw const ValidationException('Amount must be more than 0.');
    if (e.description.trim().isEmpty) throw const ValidationException('Describe the expense.');
    if (e.date.isAfter(DateTime.now())) throw const ValidationException("Date can't be in the future.");
    await _expenses.put(e);
  });

  Future<void> deleteExpense(String id) => _write(() async {
    final e = _expenses.byId(id);
    if (e?.linkedId != null) {
      // Unlink so the stock / health record stays valid.
      final h = _health.byId(e!.linkedId!);
      if (h != null) await _health.put(HealthRecord.fromJson({...h.toJson(), 'expenseId': null, 'cost': 0}));
      final m = _movements.byId(e.linkedId!);
      if (m != null) await _movements.put(StockMovement.fromJson({...m.toJson(), 'expenseId': null}));
    }
    await _expenses.remove(id);
  });

  // ───────────────────────── Inventory ─────────────────────────

  List<InventoryItem> get items => _items.all..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  InventoryItem? item(String? id) => _items.byId(id);
  double stockOf(String itemId) => _movements.all.where((m) => m.itemId == itemId).fold(0.0, (s, m) => s + m.signed);
  bool isLow(InventoryItem i) => stockOf(i.id) <= i.lowStockLevel;
  List<InventoryItem> get lowStockItems => items.where(isLow).toList();
  List<StockMovement> movementsOf(String itemId) => _movements.all.where((m) => m.itemId == itemId).toList()..sort((a, b) => b.date.compareTo(a.date));

  /// Average daily use over the last 14 days, used to predict when stock runs out.
  double dailyUse(String itemId) {
    final r = DateRange.lastDays(14);
    final used = _movements.all.where((m) => m.itemId == itemId && m.type == MovementType.stockOut && r.contains(m.date)).fold(0.0, (s, m) => s + m.quantity);
    return used / 14;
  }

  int? daysLeft(String itemId) {
    final use = dailyUse(itemId);
    if (use <= 0) return null;
    return (stockOf(itemId) / use).floor();
  }

  Future<InventoryItem> saveItem(InventoryItem i, {double openingStock = 0}) => _write(() async {
    if (i.name.trim().isEmpty) throw const ValidationException('Enter the item name.');
    if (_items.all.any((x) => x.id != i.id && x.name.trim().toLowerCase() == i.name.trim().toLowerCase())) {
      throw ValidationException('"${i.name}" is already in your store.');
    }
    final isNew = !_items.contains(i.id);
    await _items.put(i);
    if (isNew && openingStock > 0) {
      await _movements.put(
        StockMovement(id: newId(), itemId: i.id, date: DateTime.now(), type: MovementType.stockIn, quantity: openingStock, notes: 'Opening stock'),
      );
    }
    return i;
  });

  Future<void> deleteItem(String id) => _write(() async {
    await _movements.removeWhere((m) => m.itemId == id);
    await _items.remove(id);
  });

  Future<void> stockIn(String itemId, DateTime date, double qty, double? cost, {bool recordExpense = true, String notes = ''}) => _write(() async {
    final it = _items.byId(itemId);
    if (it == null) throw const NotFoundException('Item not found.');
    if (qty <= 0) throw const ValidationException('Quantity must be more than 0.');
    if (date.isAfter(DateTime.now())) throw const ValidationException("Date can't be in the future.");
    final mId = newId();
    String? exId;
    if (recordExpense && (cost ?? 0) > 0) {
      exId = newId();
      await _expenses.put(
        Expense(
          id: exId,
          date: date,
          category: it.category == ItemCategory.feed
              ? ExpenseCategory.feed
              : it.category == ItemCategory.supplies
              ? ExpenseCategory.equipment
              : ExpenseCategory.vet,
          amount: cost!,
          description: 'Bought ${Fmt.number(qty, decimals: qty % 1 == 0 ? 0 : 1)} ${it.unit} ${it.name}',
          linkedId: mId,
        ),
      );
    }
    await _movements.put(
      StockMovement(id: mId, itemId: itemId, date: date, type: MovementType.stockIn, quantity: qty, totalCost: cost, expenseId: exId, notes: notes),
    );
    if (cost != null && cost > 0) await _items.put(it.copyWith(unitCost: cost / qty));
  });

  Future<void> stockOut(String itemId, DateTime date, double qty, {TargetType? targetType, String? targetId, String notes = ''}) => _write(() async {
    final it = _items.byId(itemId);
    if (it == null) throw const NotFoundException('Item not found.');
    if (qty <= 0) throw const ValidationException('Quantity must be more than 0.');
    final have = stockOf(itemId);
    if (qty > have + 0.0001) {
      throw ValidationException('Only ${Fmt.number(have, decimals: have % 1 == 0 ? 0 : 1)} ${it.unit} of ${it.name} left in store.');
    }
    await _movements.put(
      StockMovement(
        id: newId(),
        itemId: itemId,
        date: date,
        type: MovementType.stockOut,
        quantity: qty,
        targetType: targetType,
        targetId: targetId,
        notes: notes,
      ),
    );
  });

  Future<void> deleteMovement(String id) => _write(() async {
    final m = _movements.byId(id);
    if (m == null) return;
    if (m.type == MovementType.stockIn && stockOf(m.itemId) - m.quantity < -0.0001) {
      throw const ValidationException('Some of this stock is already used. Removing it would make stock negative.');
    }
    if (m.expenseId != null) await _expenses.remove(m.expenseId!);
    await _movements.remove(id);
  });

  double feedUsedIn(DateRange r) => _movements.all
      .where((m) => m.type == MovementType.stockOut && r.contains(m.date) && _items.byId(m.itemId)?.category == ItemCategory.feed)
      .fold(0.0, (s, m) => s + m.quantity);

  // ───────────────────────── Tasks ─────────────────────────

  List<FarmTask> get tasks => _tasks.all..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<FarmTask> tasksFor(DateTime day) =>
      tasks.where((t) => t.repeatDaily ? !t.dueDate.isAfter(day) || t.dueDate.isSameDay(day) : t.dueDate.isSameDay(day)).toList();

  List<FarmTask> get pendingTasks {
    final today = dateOnly(DateTime.now());
    return tasks.where((t) => t.repeatDaily ? !t.doneOn(today) : !t.done).toList();
  }

  Future<void> saveTask(FarmTask t) => _write(() async {
    if (t.title.trim().isEmpty) throw const ValidationException('Enter what needs to be done.');
    await _tasks.put(t);
  });

  Future<void> toggleTask(String id) => _write(() async {
    final t = _tasks.byId(id);
    if (t == null) return;
    final today = DateTime.now();
    if (t.repeatDaily) {
      final doneToday = t.doneOn(today);
      await _tasks.put(doneToday ? t.copyWith(clearDoneAt: true) : t.copyWith(doneAt: today));
    } else {
      await _tasks.put(t.done ? t.copyWith(done: false, clearDoneAt: true) : t.copyWith(done: true, doneAt: today));
    }
  });

  Future<void> deleteTask(String id) => _write(() => _tasks.remove(id));

  // ───────────────────────── Alerts ─────────────────────────

  List<FarmAlert> get alerts {
    final now = DateTime.now();
    final today = dateOnly(now);
    final dismissed = dismissedAlerts;
    final out = <FarmAlert>[];

    for (final b in _breedings.all) {
      final sow = _pigs.byId(b.sowId);
      if (sow == null || !sow.isActive) continue;
      if (b.status.isOpen) {
        final due = b.expectedFarrowing;
        final days = dateOnly(due).difference(today).inDays;
        if (days <= 10) {
          out.add(
            FarmAlert(
              id: 'farrow-${b.id}',
              kind: AlertKind.farrowing,
              title: days < 0 ? '${sow.displayName} is overdue to farrow' : '${sow.displayName} due to farrow ${Fmt.relativeDay(due).toLowerCase()}',
              subtitle: days < 0 ? 'Expected ${Fmt.dateShort(due)} · check her now' : 'Prepare the farrowing pen · ${Fmt.date(due)}',
              date: due,
              severity: days <= 3 ? AlertSeverity.urgent : AlertSeverity.warning,
              targetId: sow.id,
            ),
          );
        }
      }
      if (b.status == BreedingStatus.served) {
        final d = dateOnly(b.heatCheckDate).difference(today).inDays;
        if (d >= -3 && d <= 2) {
          out.add(
            FarmAlert(
              id: 'heat-${b.id}',
              kind: AlertKind.heatCheck,
              title: 'Heat check for ${sow.displayName}',
              subtitle: '21 days after service. If no heat, confirm pregnancy.',
              date: b.heatCheckDate,
              severity: AlertSeverity.info,
              targetId: sow.id,
            ),
          );
        }
      }
      if (b.status == BreedingStatus.farrowed && b.expectedWeaning != null) {
        final d = dateOnly(b.expectedWeaning!).difference(today).inDays;
        if (d <= 3) {
          out.add(
            FarmAlert(
              id: 'wean-${b.id}',
              kind: AlertKind.weaning,
              title: 'Wean ${sow.displayName}\'s litter',
              subtitle: '${b.bornAlive ?? 0} piglets · ${Fmt.relativeDay(b.expectedWeaning!)}',
              date: b.expectedWeaning!,
              severity: d < 0 ? AlertSeverity.warning : AlertSeverity.info,
              targetId: sow.id,
            ),
          );
        }
      }
    }

    for (final h in _health.all.where((h) => h.hasOpenFollowUp)) {
      final active = h.targetType == TargetType.pig ? (_pigs.byId(h.targetId)?.isActive ?? false) : (_flocks.byId(h.targetId)?.isActive ?? false);
      if (!active) continue;
      final d = dateOnly(h.nextDue!).difference(today).inDays;
      if (d <= 5) {
        out.add(
          FarmAlert(
            id: 'health-${h.id}',
            kind: AlertKind.healthDue,
            title: '${h.product} due for ${targetName(h.targetType, h.targetId)}',
            subtitle: '${h.type.label} · ${d < 0 ? 'overdue by ${-d} ${-d == 1 ? 'day' : 'days'}' : Fmt.relativeDay(h.nextDue!)}',
            date: h.nextDue!,
            severity: d <= 0 ? AlertSeverity.urgent : AlertSeverity.warning,
            targetId: h.id,
          ),
        );
      }
    }

    for (final i in _items.all) {
      final have = stockOf(i.id);
      final left = daysLeft(i.id);
      if (have <= i.lowStockLevel || (left != null && left <= 5)) {
        out.add(
          FarmAlert(
            id: 'stock-${i.id}-${have.toStringAsFixed(1)}',
            kind: AlertKind.lowStock,
            title: have <= 0 ? '${i.name} is out of stock' : '${i.name} is running low',
            subtitle: '${Fmt.number(have, decimals: have % 1 == 0 ? 0 : 1)} ${i.unit} left${left != null ? ' · about $left days' : ''}',
            date: now,
            severity: have <= 0 ? AlertSeverity.urgent : AlertSeverity.warning,
            targetId: i.id,
          ),
        );
      }
      if (i.expiryDate != null && (i.isExpired || i.expiresSoon) && have > 0) {
        out.add(
          FarmAlert(
            id: 'exp-${i.id}',
            kind: AlertKind.expiry,
            title: i.isExpired ? '${i.name} has expired' : '${i.name} expires soon',
            subtitle: 'Expiry ${Fmt.date(i.expiryDate!)}',
            date: i.expiryDate!,
            severity: i.isExpired ? AlertSeverity.urgent : AlertSeverity.info,
            targetId: i.id,
          ),
        );
      }
    }

    for (final s in unpaidSales.where((s) => today.difference(dateOnly(s.date)).inDays >= 7)) {
      out.add(
        FarmAlert(
          id: 'debt-${s.id}-${s.balance.toStringAsFixed(0)}',
          kind: AlertKind.debt,
          title: '${s.customerName.isEmpty ? 'A customer' : s.customerName} owes ${Fmt.money(s.balance)}',
          subtitle: '${s.receiptLabel} · ${s.product.label} · ${Fmt.relativeDay(s.date)}',
          date: s.date,
          severity: today.difference(dateOnly(s.date)).inDays > 30 ? AlertSeverity.urgent : AlertSeverity.info,
          targetId: s.id,
        ),
      );
    }

    for (final t in _tasks.all.where((t) => !t.repeatDaily && !t.done && dateOnly(t.dueDate).isBefore(today))) {
      out.add(
        FarmAlert(
          id: 'task-${t.id}',
          kind: AlertKind.task,
          title: 'Overdue: ${t.title}',
          subtitle: 'Was due ${Fmt.relativeDay(t.dueDate).toLowerCase()}',
          date: t.dueDate,
          severity: t.priority == TaskPriority.high ? AlertSeverity.urgent : AlertSeverity.warning,
          targetId: t.id,
        ),
      );
    }

    out.removeWhere((a) => dismissed.contains(a.id));
    out.sort((a, b) {
      final s = b.severity.index.compareTo(a.severity.index);
      return s != 0 ? s : a.date.compareTo(b.date);
    });
    return out;
  }

  // ───────────────────────── Backup ─────────────────────────

  Map<String, dynamic> exportBackup() => {
    'app': 'shamba',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'farm': _farm?.toJson(),
    'receiptSeq': _meta.get('receiptSeq') ?? 0,
    'data': {
      'pigs': _pigs.export(),
      'weights': _weights.export(),
      'breedings': _breedings.export(),
      'flocks': _flocks.export(),
      'eggs': _eggs.export(),
      'mortality': _mortality.export(),
      'health': _health.export(),
      'sales': _sales.export(),
      'customers': _customers.export(),
      'expenses': _expenses.export(),
      'items': _items.export(),
      'movements': _movements.export(),
      'tasks': _tasks.export(),
    },
  };

  /// Replaces all data with a backup file. Returns the number of skipped rows.
  Future<int> importBackup(String raw) => _write(() async {
    Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      throw const ValidationException('This file is not a Shamba backup.');
    }
    if (json is! Map || json['app'] != 'shamba' || json['data'] is! Map) {
      throw const ValidationException('This file is not a Shamba backup.');
    }
    final d = json['data'] as Map;
    List rows(String k) => d[k] is List ? d[k] as List : const [];
    var skipped = 0;
    skipped += await _pigs.importRows(rows('pigs'));
    skipped += await _weights.importRows(rows('weights'));
    skipped += await _breedings.importRows(rows('breedings'));
    skipped += await _flocks.importRows(rows('flocks'));
    skipped += await _eggs.importRows(rows('eggs'));
    skipped += await _mortality.importRows(rows('mortality'));
    skipped += await _health.importRows(rows('health'));
    skipped += await _sales.importRows(rows('sales'));
    skipped += await _customers.importRows(rows('customers'));
    skipped += await _expenses.importRows(rows('expenses'));
    skipped += await _items.importRows(rows('items'));
    skipped += await _movements.importRows(rows('movements'));
    skipped += await _tasks.importRows(rows('tasks'));
    if (json['farm'] is Map) {
      final f = FarmProfile.fromJson(json['farm'] as Map);
      await _meta.put('farm', jsonEncode(f.toJson()));
      _farm = f;
      Fmt.currency = f.currency;
    }
    await _meta.put('receiptSeq', json['receiptSeq'] is int ? json['receiptSeq'] : _sales.length);
    return skipped;
  });

  Future<void> clearAllData() => _write(() async {
    for (final c in _all) {
      await c.clear();
    }
    await _meta.put('receiptSeq', 0);
    await _meta.delete('dismissed');
  });

  bool get isEmpty => _pigs.length == 0 && _flocks.length == 0 && _sales.length == 0;

  /// Fills the farm with three months of realistic records so every screen can be explored.
  Future<void> loadDemoData() => _write(() async {
    final d = DemoData.build(eggsPerTray: eggsPerTray);
    await _pigs.putAll(d.pigs);
    await _weights.putAll(d.weights);
    await _breedings.putAll(d.breedings);
    await _flocks.putAll(d.flocks);
    await _eggs.putAll(d.eggs);
    await _mortality.putAll(d.mortality);
    await _health.putAll(d.health);
    await _customers.putAll(d.customers);
    await _sales.putAll(d.sales);
    await _expenses.putAll(d.expenses);
    await _items.putAll(d.items);
    await _movements.putAll(d.movements);
    await _tasks.putAll(d.tasks);
    await _meta.put('receiptSeq', d.sales.length);
  });
}
