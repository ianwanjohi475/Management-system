import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:shamba/core/errors/app_exception.dart';
import 'package:shamba/core/utils/ids.dart';
import 'package:shamba/data/models/models.dart';
import 'package:shamba/data/storage/local_db.dart';
import 'package:shamba/state/auth_controller.dart';
import 'package:shamba/state/farm_store.dart';

void main() {
  late Directory dir;
  late FarmStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('shamba_test');
    LocalDb.initAt(dir.path);
    store = FarmStore();
    await store.open(newId());
    await store.saveFarm(FarmProfile(name: 'Test Farm', location: 'Kiambu', birdTypes: {BirdType.layers, BirdType.broilers}));
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));

  Future<Flock> layers({int count = 100}) => store.saveFlock(
    Flock(
      id: newId(),
      name: 'Layers A',
      type: BirdType.layers,
      breed: 'ISA Brown',
      initialCount: count,
      startDate: now.subtract(const Duration(days: 60)),
      createdAt: now,
    ),
  );

  Future<Pig> pig(String tag, {Sex sex = Sex.female, PigStage stage = PigStage.grower}) =>
      store.savePig(Pig(id: newId(), tag: tag, sex: sex, breed: 'Large White', stage: stage, acquiredDate: now, createdAt: now));

  group('eggs', () {
    test('cannot sell more eggs than in stock', () async {
      final f = await layers();
      await store.saveEggs(EggRecord(id: newId(), flockId: f.id, date: yesterday, collected: 95, broken: 5));
      expect(store.eggStock, 90);
      await store.createSale(date: now, product: Product.eggs, quantity: 2, unitPrice: 450, amountPaid: 900);
      expect(store.eggStock, 30);
      expect(() => store.createSale(date: now, product: Product.eggs, quantity: 2, unitPrice: 450, amountPaid: 900), throwsA(isA<ValidationException>()));
    });

    test('rejects duplicate day, broken > collected and impossible counts', () async {
      final f = await layers(count: 50);
      await store.saveEggs(EggRecord(id: newId(), flockId: f.id, date: yesterday, collected: 40));
      expect(() => store.saveEggs(EggRecord(id: newId(), flockId: f.id, date: yesterday, collected: 10)), throwsA(isA<ValidationException>()));
      expect(() => store.saveEggs(EggRecord(id: newId(), flockId: f.id, date: now, collected: 10, broken: 11)), throwsA(isA<ValidationException>()));
      expect(() => store.saveEggs(EggRecord(id: newId(), flockId: f.id, date: now, collected: 500)), throwsA(isA<ValidationException>()));
    });

    test('cannot delete eggs that were already sold', () async {
      final f = await layers();
      final rec = EggRecord(id: newId(), flockId: f.id, date: yesterday, collected: 60);
      await store.saveEggs(rec);
      await store.createSale(date: now, product: Product.eggs, quantity: 2, unitPrice: 450, amountPaid: 900);
      expect(() => store.deleteEggs(rec.id), throwsA(isA<ValidationException>()));
    });
  });

  group('poultry', () {
    test('birds alive goes down with deaths and sales, never below zero', () async {
      final f = await layers(count: 20);
      await store.addMortality(MortalityRecord(id: newId(), flockId: f.id, date: now, count: 5, cause: 'Disease'));
      await store.createSale(date: now, product: Product.liveChicken, quantity: 10, unitPrice: 900, flockId: f.id, amountPaid: 9000);
      expect(store.birdsAlive(f.id), 5);
      expect(() => store.addMortality(MortalityRecord(id: newId(), flockId: f.id, date: now, count: 6, cause: 'x')), throwsA(isA<ValidationException>()));
      expect(
        () => store.createSale(date: now, product: Product.liveChicken, quantity: 6, unitPrice: 900, flockId: f.id, amountPaid: 5400),
        throwsA(isA<ValidationException>()),
      );
    });

    test('flock purchase cost becomes an expense', () async {
      await store.saveFlock(
        Flock(id: newId(), name: 'Broilers', type: BirdType.broilers, breed: 'Cobb 500', initialCount: 100, startDate: now, costPerBird: 90, createdAt: now),
      );
      expect(store.expenseTotalIn(DateRange.thisMonth()), 9000);
    });
  });

  group('pigs & sales', () {
    test('selling pigs marks them sold; deleting the sale restores them', () async {
      final a = await pig('P-001');
      final b = await pig('P-002');
      final sale = await store.createSale(
        date: now,
        product: Product.pig,
        quantity: 2,
        unitPrice: 20000,
        pigIds: [a.id, b.id],
        customerName: 'Kamau Butchery',
        customerPhone: '0722 908 070',
        amountPaid: 30000,
      );
      expect(store.activePigs, isEmpty);
      expect(sale.balance, 10000);
      expect(store.customers.single.name, 'Kamau Butchery');
      expect(store.totalOwed, 10000);
      await store.deleteSale(sale.id);
      expect(store.activePigs.length, 2);
    });

    test('duplicate active tag rejected', () async {
      await pig('P-010');
      expect(() => pig('p-010'), throwsA(isA<ValidationException>()));
    });

    test('credit sale needs a buyer name', () async {
      final a = await pig('P-003');
      expect(() => store.createSale(date: now, product: Product.pig, quantity: 1, unitPrice: 20000, pigIds: [a.id]), throwsA(isA<ValidationException>()));
    });

    test('payments cannot exceed the balance', () async {
      final sale = await store.createSale(date: now, product: Product.manure, quantity: 10, unitPrice: 300, customerName: 'Mama Wanjiru');
      expect(sale.paymentStatus, PaymentStatus.unpaid);
      expect(() => store.addPayment(sale.id, Payment(date: now, amount: 5000, method: PaymentMethod.cash)), throwsA(isA<ValidationException>()));
      await store.addPayment(sale.id, Payment(date: now, amount: 3000, method: PaymentMethod.mpesa));
      expect(store.sale(sale.id)!.paymentStatus, PaymentStatus.paid);
      expect(store.totalOwed, 0);
    });
  });

  group('breeding', () {
    test('service → farrowing in 114 days, farrowing adds piglets, weaning moves them on', () async {
      final sow = await pig('S-1', stage: PigStage.gilt);
      final service = BreedingRecord(id: newId(), sowId: sow.id, serviceDate: now.subtract(const Duration(days: 112)));
      await store.addBreeding(service);
      expect(service.expectedFarrowing.difference(service.serviceDate).inDays, 114);
      expect(store.alerts.any((a) => a.kind == AlertKind.farrowing), isTrue);
      expect(() => store.addBreeding(BreedingRecord(id: newId(), sowId: sow.id, serviceDate: now)), throwsA(isA<ValidationException>()));

      final added = await store.recordFarrowing(service.id, date: now, bornAlive: 9, stillborn: 1, addPiglets: true);
      expect(added, 9);
      expect(store.pig(sow.id)!.stage, PigStage.sow);
      expect(store.offspringOf(sow.id).length, 9);

      await store.recordWeaning(service.id, now, 8);
      expect(store.offspringOf(sow.id).every((p) => p.stage == PigStage.weaner), isTrue);
    });

    test('males cannot be served', () async {
      final boar = await pig('B-1', sex: Sex.male, stage: PigStage.boar);
      expect(() => store.addBreeding(BreedingRecord(id: newId(), sowId: boar.id, serviceDate: now)), throwsA(isA<ValidationException>()));
    });
  });

  group('inventory', () {
    test('cannot use more stock than available; purchases create expenses', () async {
      final item = await store.saveItem(
        InventoryItem(id: newId(), name: 'Layers Mash', category: ItemCategory.feed, unit: 'kg', lowStockLevel: 50, createdAt: now),
      );
      await store.stockIn(item.id, now, 70, 3500);
      expect(store.stockOf(item.id), 70);
      expect(store.expenseTotalIn(DateRange.thisMonth()), 3500);
      await store.stockOut(item.id, now, 30);
      expect(store.isLow(item), isTrue);
      expect(store.alerts.any((a) => a.kind == AlertKind.lowStock), isTrue);
      expect(() => store.stockOut(item.id, now, 41), throwsA(isA<ValidationException>()));
    });
  });

  group('data', () {
    test('demo data is consistent', () async {
      await store.loadDemoData();
      expect(store.eggStock, greaterThan(0));
      for (final f in store.flocks) {
        expect(store.birdsAlive(f.id), greaterThanOrEqualTo(0));
      }
      for (final i in store.items) {
        expect(store.stockOf(i.id), greaterThanOrEqualTo(0), reason: i.name);
      }
      expect(store.sales.map((s) => s.receiptNo).toSet().length, store.sales.length);
      expect(store.alerts, isNotEmpty);
    });

    test('backup round-trip restores everything; bad files are rejected', () async {
      await store.loadDemoData();
      final backup = store.exportBackup();
      final sales = store.sales.length, pigs = store.pigs.length;
      await store.clearAllData();
      expect(store.isEmpty, isTrue);
      final skipped = await store.importBackup(jsonEncode(backup));
      expect(skipped, 0);
      expect(store.sales.length, sales);
      expect(store.pigs.length, pigs);
      expect(() => store.importBackup('{"hello": 1}'), throwsA(isA<ValidationException>()));
      expect(() => store.importBackup('not json'), throwsA(isA<ValidationException>()));
    });
  });

  group('auth', () {
    test('sign up, duplicate email, wrong password and reset', () async {
      final auth = AuthController();
      await auth.init();
      await auth.signUp(name: 'Ian W', email: 'Ian@Farm.co.ke', phone: '0712 345 678', password: 'kuku2024');
      expect(auth.user!.email, 'ian@farm.co.ke');
      expect(() => auth.signUp(name: 'X', email: 'ian@farm.co.ke', phone: '0700000000', password: 'abc123'), throwsA(isA<AuthException>()));
      await auth.logout();
      expect(() => auth.login('ian@farm.co.ke', 'wrong1'), throwsA(isA<AuthException>()));
      expect(() => auth.resetPassword(email: 'ian@farm.co.ke', phone: '0799 999 999', newPassword: 'new123'), throwsA(isA<AuthException>()));
      await auth.resetPassword(email: 'ian@farm.co.ke', phone: '+254712345678', newPassword: 'new123');
      await auth.login('ian@farm.co.ke', 'new123');
      expect(auth.isLoggedIn, isTrue);
    });
  });
}
