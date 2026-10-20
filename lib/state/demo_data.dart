import 'dart:math';

import '../core/utils/formatters.dart';
import '../core/utils/ids.dart';
import '../data/models/models.dart';

/// Builds a consistent, realistic sample farm covering the last ~90 days.
class DemoData {
  DemoData._();

  final pigs = <Pig>[];
  final weights = <WeightRecord>[];
  final breedings = <BreedingRecord>[];
  final flocks = <Flock>[];
  final eggs = <EggRecord>[];
  final mortality = <MortalityRecord>[];
  final health = <HealthRecord>[];
  final customers = <Customer>[];
  final sales = <Sale>[];
  final expenses = <Expense>[];
  final items = <InventoryItem>[];
  final movements = <StockMovement>[];
  final tasks = <FarmTask>[];

  static DemoData build({int eggsPerTray = 30}) {
    final d = DemoData._();
    final r = Random(42);
    final now = DateTime.now();
    final today = dateOnly(now);
    DateTime ago(int days) => today.subtract(Duration(days: days)).add(Duration(hours: 7 + r.nextInt(10)));

    // ── Pigs ──
    Pig pig(String tag, String name, Sex sex, PigStage stage, int ageDays, String breed, {String pen = 'Pen 1', String? mother}) {
      final p = Pig(
        id: newId(),
        tag: tag,
        name: name,
        sex: sex,
        breed: breed,
        stage: stage,
        birthDate: today.subtract(Duration(days: ageDays)),
        acquiredDate: today.subtract(Duration(days: min(ageDays, 200))),
        pen: pen,
        motherId: mother,
        createdAt: now,
      );
      d.pigs.add(p);
      return p;
    }

    final boar = pig('P-001', 'Bingwa', Sex.male, PigStage.boar, 620, 'Duroc', pen: 'Boar pen');
    final sow1 = pig('P-002', 'Neema', Sex.female, PigStage.sow, 540, 'Large White', pen: 'Farrowing 1');
    final sow2 = pig('P-003', 'Baraka', Sex.female, PigStage.sow, 480, 'Landrace', pen: 'Farrowing 2');
    final sow3 = pig('P-004', 'Zawadi', Sex.female, PigStage.gilt, 250, 'Large White × Landrace', pen: 'Sow pen');
    final growers = <Pig>[];
    for (var i = 0; i < 8; i++) {
      growers.add(
        pig(
          'P-${(5 + i).toString().padLeft(3, '0')}',
          '',
          i.isEven ? Sex.male : Sex.female,
          i < 4 ? PigStage.finisher : PigStage.grower,
          i < 4 ? 160 + r.nextInt(15) : 105 + r.nextInt(10),
          'Large White × Landrace',
          pen: i < 4 ? 'Finisher pen' : 'Grower pen',
          mother: sow1.id,
        ),
      );
    }
    final piglets = <Pig>[];
    for (var i = 0; i < 6; i++) {
      piglets.add(
        pig(
          'P-${(13 + i).toString().padLeft(3, '0')}',
          '',
          i.isEven ? Sex.female : Sex.male,
          PigStage.piglet,
          18,
          'Large White × Duroc',
          pen: 'Farrowing 2',
          mother: sow2.id,
        ),
      );
    }

    // Weights: growth curves
    for (final p in [...growers, boar, sow1, sow2, sow3]) {
      final age = today.difference(p.birthDate!).inDays;
      for (var w = 0; w < 6; w++) {
        final daysAgo = 75 - w * 15;
        final a = age - daysAgo;
        if (a < 10) continue;
        final kg = p.stage == PigStage.boar || p.stage == PigStage.sow ? 150 + a * 0.05 + r.nextDouble() * 4 : 1.4 + a * 0.62 + r.nextDouble() * 3;
        d.weights.add(WeightRecord(id: newId(), pigId: p.id, date: ago(daysAgo), kg: double.parse(kg.toStringAsFixed(1))));
      }
    }

    // Breeding: sow1 pregnant (due in 4 days), sow2 farrowed 18 days ago, gilt served 19 days ago.
    d.breedings.addAll([
      BreedingRecord(
        id: newId(),
        sowId: sow1.id,
        boarId: boar.id,
        boarName: boar.displayName,
        serviceDate: today.subtract(const Duration(days: 110)),
        status: BreedingStatus.pregnant,
      ),
      BreedingRecord(
        id: newId(),
        sowId: sow2.id,
        boarId: boar.id,
        boarName: boar.displayName,
        serviceDate: today.subtract(const Duration(days: 132)),
        status: BreedingStatus.farrowed,
        farrowDate: today.subtract(const Duration(days: 18)),
        bornAlive: 6,
        stillborn: 1,
      ),
      BreedingRecord(id: newId(), sowId: sow3.id, boarName: 'A.I. – KALRO', method: ServiceMethod.ai, serviceDate: today.subtract(const Duration(days: 19))),
    ]);

    // ── Flocks ──
    final layers = Flock(
      id: newId(),
      name: 'Layers House A',
      type: BirdType.layers,
      breed: 'ISA Brown',
      initialCount: 300,
      startDate: today.subtract(const Duration(days: 150)),
      ageAtStartWeeks: 18,
      house: 'House A',
      costPerBird: 650,
      createdAt: now,
    );
    final kienyeji = Flock(
      id: newId(),
      name: 'Kienyeji Batch 2',
      type: BirdType.kienyeji,
      breed: 'Kuroiler',
      initialCount: 120,
      startDate: today.subtract(const Duration(days: 140)),
      ageAtStartWeeks: 4,
      house: 'Free range',
      costPerBird: 180,
      createdAt: now,
    );
    final broilers = Flock(
      id: newId(),
      name: 'Broilers Batch 7',
      type: BirdType.broilers,
      breed: 'Cobb 500',
      initialCount: 200,
      startDate: today.subtract(const Duration(days: 33)),
      house: 'House B',
      costPerBird: 95,
      createdAt: now,
    );
    d.flocks.addAll([layers, kienyeji, broilers]);
    for (final f in d.flocks) {
      d.expenses.add(
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

    // Eggs: 90 days
    var eggsCollected = 0;
    for (var day = 89; day >= 0; day--) {
      final rateL = 0.80 + r.nextDouble() * 0.1;
      final c = (288 * rateL).round();
      final b = r.nextInt(6);
      d.eggs.add(EggRecord(id: newId(), flockId: layers.id, date: ago(day), collected: c, broken: b));
      eggsCollected += c - b;
      if (day % 2 == 0 || day < 14) {
        final ck = 30 + r.nextInt(14);
        d.eggs.add(EggRecord(id: newId(), flockId: kienyeji.id, date: ago(day), collected: ck, broken: r.nextInt(2)));
        eggsCollected += ck;
      }
    }

    // Mortality
    for (final m in [
      (layers, 48, 3, 'Disease'),
      (layers, 20, 2, 'Heat stress'),
      (layers, 6, 1, 'Unknown'),
      (kienyeji, 70, 4, 'Predator'),
      (kienyeji, 12, 2, 'Disease'),
      (broilers, 30, 6, 'Cold / brooding'),
      (broilers, 22, 3, 'Unknown'),
      (broilers, 4, 2, 'Injury'),
    ]) {
      d.mortality.add(MortalityRecord(id: newId(), flockId: m.$1.id, date: ago(m.$2), count: m.$3, cause: m.$4));
    }

    // Health
    HealthRecord h(TargetType t, String id, int daysAgo, HealthType type, String product, double cost, {int? nextInDays, String dose = ''}) {
      final rec = HealthRecord(
        id: newId(),
        targetType: t,
        targetId: id,
        date: ago(daysAgo),
        type: type,
        product: product,
        dose: dose,
        cost: cost,
        administeredBy: 'Dr. Mwangi',
        nextDue: nextInDays == null ? null : today.add(Duration(days: nextInDays)),
      );
      d.health.add(rec);
      if (cost > 0) {
        final ex = Expense(id: newId(), date: rec.date, category: ExpenseCategory.vet, amount: cost, description: '${type.label}: $product', linkedId: rec.id);
        d.expenses.add(ex);
        d.health[d.health.length - 1] = rec.copyWith(expenseId: ex.id);
      }
      return rec;
    }

    h(TargetType.flock, broilers.id, 26, HealthType.vaccination, 'Gumboro (IBD)', 1200, dose: 'Drinking water');
    h(TargetType.flock, broilers.id, 12, HealthType.vaccination, 'Gumboro booster', 1200, nextInDays: 0, dose: 'Drinking water');
    h(TargetType.flock, layers.id, 85, HealthType.vaccination, 'Newcastle (Lasota)', 2500, nextInDays: 2, dose: 'Drinking water');
    h(TargetType.flock, kienyeji.id, 40, HealthType.deworming, 'Piperazine', 800, nextInDays: 50);
    h(TargetType.pig, sow2.id, 17, HealthType.vitamins, 'Iron injection – piglets', 900, dose: '1 ml each');
    h(TargetType.pig, growers.first.id, 30, HealthType.deworming, 'Ivermectin', 650, nextInDays: 60, dose: '1 ml / 33 kg');
    h(TargetType.pig, sow1.id, 60, HealthType.vaccination, 'Erysipelas', 1500, nextInDays: 120);

    // Inventory
    InventoryItem item(String name, ItemCategory c, String unit, double low, double unitCost, {DateTime? expiry, String supplier = ''}) {
      final i = InventoryItem(
        id: newId(),
        name: name,
        category: c,
        unit: unit,
        lowStockLevel: low,
        unitCost: unitCost,
        expiryDate: expiry,
        supplier: supplier,
        createdAt: now,
      );
      d.items.add(i);
      return i;
    }

    final layersMash = item('Layers Mash', ItemCategory.feed, 'kg', 300, 52, supplier: 'Unga Farm Care');
    final broilerFinisher = item('Broiler Finisher', ItemCategory.feed, 'kg', 150, 68, supplier: 'Pembe Feeds');
    final pigGrower = item('Pig Grower Meal', ItemCategory.feed, 'kg', 200, 48, supplier: 'Sigma Feeds');
    final sowMeal = item('Sow & Weaner Meal', ItemCategory.feed, 'kg', 100, 55);
    item('Newcastle Vaccine (Lasota)', ItemCategory.vaccine, 'doses', 300, 5, expiry: today.add(const Duration(days: 20)));
    final oxy = item('Oxytetracycline 20%', ItemCategory.medicine, 'bottles', 2, 750, expiry: today.add(const Duration(days: 200)));
    item('Disinfectant', ItemCategory.supplies, 'litres', 5, 420);

    void buy(InventoryItem i, int daysAgo, double qty) {
      final mId = newId(), exId = newId();
      final cost = qty * (i.unitCost ?? 0);
      d.movements.add(StockMovement(id: mId, itemId: i.id, date: ago(daysAgo), type: MovementType.stockIn, quantity: qty, totalCost: cost, expenseId: exId));
      d.expenses.add(
        Expense(
          id: exId,
          date: ago(daysAgo),
          category: i.category == ItemCategory.feed
              ? ExpenseCategory.feed
              : i.category == ItemCategory.supplies
              ? ExpenseCategory.equipment
              : ExpenseCategory.vet,
          amount: cost,
          description: 'Bought ${qty.toStringAsFixed(0)} ${i.unit} ${i.name}',
          linkedId: mId,
        ),
      );
    }

    // Feed is drawn from the store every few days, like most farms record it.
    void use(InventoryItem i, int fromDay, double perDay, TargetType t, String target) {
      for (var day = fromDay; day >= 1; day -= 3) {
        final days = day >= 3 ? 3 : day;
        d.movements.add(
          StockMovement(id: newId(), itemId: i.id, date: ago(day), type: MovementType.stockOut, quantity: perDay * days, targetType: t, targetId: target),
        );
      }
    }

    for (final x in [(layersMash, 88), (layersMash, 60), (layersMash, 32), (layersMash, 5)]) {
      buy(x.$1, x.$2, 1050);
    }
    use(layersMash, 88, 36, TargetType.flock, layers.id);
    buy(broilerFinisher, 33, 900);
    buy(broilerFinisher, 14, 700);
    use(broilerFinisher, 33, 44, TargetType.flock, broilers.id);
    buy(pigGrower, 70, 1000);
    buy(pigGrower, 35, 1000);
    use(pigGrower, 70, 26, TargetType.pig, growers.first.id);
    buy(sowMeal, 50, 400);
    use(sowMeal, 50, 7, TargetType.pig, sow1.id);
    buy(oxy, 40, 4);
    for (final i in d.items.where((i) => i.category == ItemCategory.vaccine || i.category == ItemCategory.supplies)) {
      buy(i, 30, i.category == ItemCategory.vaccine ? 1000 : 20);
    }

    // Other expenses
    for (var m = 0; m < 3; m++) {
      d.expenses.add(
        Expense(
          id: newId(),
          date: ago(m * 30 + 2),
          category: ExpenseCategory.labour,
          amount: 15000,
          description: 'Farm hand salary',
          method: PaymentMethod.mpesa,
        ),
      );
      d.expenses.add(
        Expense(
          id: newId(),
          date: ago(m * 30 + 9),
          category: ExpenseCategory.utilities,
          amount: 2300 + r.nextInt(600).toDouble(),
          description: 'Water & electricity',
        ),
      );
      d.expenses.add(
        Expense(
          id: newId(),
          date: ago(m * 30 + 15),
          category: ExpenseCategory.transport,
          amount: 1200 + r.nextInt(800).toDouble(),
          description: 'Delivery to market',
        ),
      );
    }
    d.expenses.add(Expense(id: newId(), date: ago(44), category: ExpenseCategory.equipment, amount: 6500, description: 'New drinkers & feeders'));

    // ── Customers & sales ──
    Customer cust(String name, String phone, String loc) {
      final c = Customer(id: newId(), name: name, phone: phone, location: loc, createdAt: now);
      d.customers.add(c);
      return c;
    }

    final mama = cust('Mama Wanjiru', '0712 345 678', 'Kiambu market');
    final hotel = cust('Green Valley Hotel', '0733 222 111', 'Thika town');
    final butcher = cust('Kamau Butchery', '0722 908 070', 'Ruiru');
    final shop = cust('Mwangi Shop', '0701 556 223', 'Juja');
    final school = cust('St. Mary\'s School', '0798 100 200', 'Gatundu');

    var receipt = 0;
    var eggsSold = 0;
    void sale(
      int daysAgo,
      Product p,
      double qty,
      double price,
      Customer? c, {
      double? paid,
      PaymentMethod m = PaymentMethod.cash,
      String? flockId,
      List<String> pigIds = const [],
      EggUnit unit = EggUnit.tray,
      String ref = '',
    }) {
      final date = ago(daysAgo);
      final total = qty * price;
      final pay = paid ?? total;
      receipt++;
      d.sales.add(
        Sale(
          id: newId(),
          receiptNo: receipt,
          date: date,
          product: p,
          quantity: qty,
          unitPrice: price,
          eggUnit: unit,
          customerId: c?.id,
          customerName: c?.name ?? '',
          customerPhone: c?.phone ?? '',
          payments: pay > 0 ? [Payment(date: date, amount: pay, method: m, reference: ref)] : const [],
          flockId: flockId,
          pigIds: pigIds,
          createdAt: date,
        ),
      );
    }

    final buyers = [mama, hotel, shop, school, null];
    for (var day = 88; day >= 1; day -= 2) {
      final trays = 12 + r.nextInt(8);
      final eggs = trays * eggsPerTray;
      if (eggsSold + eggs > eggsCollected - 600) break;
      eggsSold += eggs;
      final c = buyers[r.nextInt(buyers.length)];
      final unpaid = c != null && day < 12 && r.nextBool();
      sale(
        day,
        Product.eggs,
        trays.toDouble(),
        480 + r.nextInt(4) * 10.0,
        c,
        paid: unpaid ? (r.nextBool() ? 0 : 2000) : null,
        m: r.nextBool() ? PaymentMethod.mpesa : PaymentMethod.cash,
        ref: 'S${r.nextInt(99999999)}',
      );
    }
    sale(60, Product.liveChicken, 10, 850, hotel, flockId: kienyeji.id, m: PaymentMethod.mpesa);
    sale(41, Product.liveChicken, 6, 900, mama, flockId: kienyeji.id);
    sale(8, Product.liveChicken, 8, 950, shop, flockId: kienyeji.id, paid: 3600);
    sale(3, Product.dressedChicken, 60, 700, hotel, flockId: broilers.id, m: PaymentMethod.bank);
    sale(1, Product.dressedChicken, 30, 700, butcher, flockId: broilers.id, paid: 0);
    sale(20, Product.manure, 12, 300, null);
    sale(52, Product.manure, 8, 300, mama);

    // Sold pigs: two finishers + old piglets
    final soldA = pig('P-019', '', Sex.male, PigStage.finisher, 190, 'Large White', pen: 'Finisher pen');
    final soldB = pig('P-020', '', Sex.female, PigStage.finisher, 192, 'Large White', pen: 'Finisher pen');
    sale(25, Product.pig, 2, 24000, butcher, pigIds: [soldA.id, soldB.id], m: PaymentMethod.mpesa, ref: 'RKT4H7Q2PX');
    for (final p in [soldA, soldB]) {
      d.pigs[d.pigs.indexOf(p)] = p.copyWith(status: PigStatus.sold, statusDate: ago(25), statusNote: 'Sold to Kamau Butchery');
    }
    final soldC = pig('P-022', '', Sex.male, PigStage.finisher, 185, 'Large White × Landrace', pen: 'Finisher pen');
    final soldD = pig('P-023', '', Sex.female, PigStage.finisher, 186, 'Large White × Landrace', pen: 'Finisher pen');
    sale(6, Product.pig, 2, 26000, butcher, pigIds: [soldC.id, soldD.id], m: PaymentMethod.mpesa, ref: 'SJK8M2N4QA');
    for (final p in [soldC, soldD]) {
      d.pigs[d.pigs.indexOf(p)] = p.copyWith(status: PigStatus.sold, statusDate: ago(6), statusNote: 'Sold to Kamau Butchery');
    }
    final dead = pig('P-021', '', Sex.female, PigStage.weaner, 70, 'Local / Cross', pen: 'Grower pen');
    d.pigs[d.pigs.indexOf(dead)] = dead.copyWith(status: PigStatus.dead, statusDate: ago(33), statusNote: 'Diarrhoea');

    d.sales.sort((a, b) => a.date.compareTo(b.date));
    for (var i = 0; i < d.sales.length; i++) {
      d.sales[i] = Sale.fromJson({...d.sales[i].toJson(), 'receiptNo': i + 1});
    }

    // ── Tasks ──
    FarmTask task(String title, int inDays, {TaskPriority p = TaskPriority.normal, bool daily = false, String notes = ''}) {
      final t = FarmTask(
        id: newId(),
        title: title,
        dueDate: today.add(Duration(days: inDays)).add(const Duration(hours: 8)),
        priority: p,
        repeatDaily: daily,
        notes: notes,
        createdAt: now,
      );
      d.tasks.add(t);
      return t;
    }

    task('Feed & water all birds', -30, daily: true);
    task('Collect eggs (morning & evening)', -30, daily: true);
    task('Feed pigs & clean pens', -30, daily: true);
    task('Prepare farrowing pen for Neema', 1, p: TaskPriority.high, notes: 'Clean, disinfect and add fresh bedding.');
    task('Buy layers mash', 2, p: TaskPriority.high);
    task('Weigh broilers for market', 3);
    task('Call vet about Zawadi heat check', 0, p: TaskPriority.normal);
    task('Repair chicken house roof', -2, p: TaskPriority.low);
    return d;
  }
}
