import 'enums.dart';

export 'enums.dart';

/// Defensive readers so a single bad field never crashes the app.
abstract final class _J {
  static String str(Map m, String k, [String d = '']) => m[k]?.toString() ?? d;
  static String? strN(Map m, String k) {
    final v = m[k]?.toString();
    return (v == null || v.isEmpty) ? null : v;
  }

  static double dbl(Map m, String k, [double d = 0]) {
    final v = m[k];
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? d;
  }

  static double? dblN(Map m, String k) {
    final v = m[k];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  static int integer(Map m, String k, [int d = 0]) {
    final v = m[k];
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? d;
  }

  static bool boolean(Map m, String k, [bool d = false]) => m[k] is bool ? m[k] as bool : d;

  static DateTime date(Map m, String k) => DateTime.tryParse('${m[k]}') ?? DateTime.now();
  static DateTime? dateN(Map m, String k) => m[k] == null ? null : DateTime.tryParse('${m[k]}');

  static List<String> strings(Map m, String k) => (m[k] is List) ? (m[k] as List).map((e) => '$e').toList() : <String>[];
}

String? _iso(DateTime? d) => d?.toIso8601String();

/// Anything stored in the database.
abstract class Entity {
  String get id;
  Map<String, dynamic> toJson();
}

// ───────────────────────── Accounts ─────────────────────────

class UserAccount implements Entity {
  UserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
  });

  @override
  final String id;
  final String name;
  final String email;
  final String phone;
  final String passwordHash;
  final String salt;
  final DateTime createdAt;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  UserAccount copyWith({String? name, String? phone, String? passwordHash, String? salt}) => UserAccount(
    id: id,
    name: name ?? this.name,
    email: email,
    phone: phone ?? this.phone,
    passwordHash: passwordHash ?? this.passwordHash,
    salt: salt ?? this.salt,
    createdAt: createdAt,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'passwordHash': passwordHash,
    'salt': salt,
    'createdAt': _iso(createdAt),
  };

  factory UserAccount.fromJson(Map m) => UserAccount(
    id: _J.str(m, 'id'),
    name: _J.str(m, 'name'),
    email: _J.str(m, 'email'),
    phone: _J.str(m, 'phone'),
    passwordHash: _J.str(m, 'passwordHash'),
    salt: _J.str(m, 'salt'),
    createdAt: _J.date(m, 'createdAt'),
  );
}

class FarmProfile implements Entity {
  FarmProfile({
    this.id = 'farm',
    required this.name,
    required this.location,
    this.currency = 'KES',
    this.keepsPigs = true,
    this.birdTypes = const {BirdType.layers},
    this.eggsPerTray = 30,
    this.defaultTrayPrice = 450,
    this.size = '',
  });

  @override
  final String id;
  final String name;
  final String location;
  final String currency;
  final bool keepsPigs;
  final Set<BirdType> birdTypes;
  final int eggsPerTray;
  final double defaultTrayPrice;
  final String size;

  bool get keepsPoultry => birdTypes.isNotEmpty;

  FarmProfile copyWith({
    String? name,
    String? location,
    String? currency,
    bool? keepsPigs,
    Set<BirdType>? birdTypes,
    int? eggsPerTray,
    double? defaultTrayPrice,
    String? size,
  }) => FarmProfile(
    id: id,
    name: name ?? this.name,
    location: location ?? this.location,
    currency: currency ?? this.currency,
    keepsPigs: keepsPigs ?? this.keepsPigs,
    birdTypes: birdTypes ?? this.birdTypes,
    eggsPerTray: eggsPerTray ?? this.eggsPerTray,
    defaultTrayPrice: defaultTrayPrice ?? this.defaultTrayPrice,
    size: size ?? this.size,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'currency': currency,
    'keepsPigs': keepsPigs,
    'birdTypes': birdTypes.map((e) => e.name).toList(),
    'eggsPerTray': eggsPerTray,
    'defaultTrayPrice': defaultTrayPrice,
    'size': size,
  };

  factory FarmProfile.fromJson(Map m) => FarmProfile(
    id: _J.str(m, 'id', 'farm'),
    name: _J.str(m, 'name', 'My Farm'),
    location: _J.str(m, 'location'),
    currency: _J.str(m, 'currency', 'KES'),
    keepsPigs: _J.boolean(m, 'keepsPigs', true),
    birdTypes: _J.strings(m, 'birdTypes').map((n) => enumByName(BirdType.values, n, BirdType.layers)).toSet(),
    eggsPerTray: _J.integer(m, 'eggsPerTray', 30).clamp(1, 100),
    defaultTrayPrice: _J.dbl(m, 'defaultTrayPrice', 450),
    size: _J.str(m, 'size'),
  );
}

// ───────────────────────── Pigs ─────────────────────────

class Pig implements Entity {
  Pig({
    required this.id,
    required this.tag,
    this.name = '',
    required this.sex,
    required this.breed,
    required this.stage,
    this.birthDate,
    required this.acquiredDate,
    this.purchased = false,
    this.purchasePrice,
    this.pen = '',
    this.status = PigStatus.active,
    this.statusDate,
    this.statusNote = '',
    this.motherId,
    this.fatherId,
    this.photo,
    this.notes = '',
    required this.createdAt,
  });

  @override
  final String id;
  final String tag;
  final String name;
  final Sex sex;
  final String breed;
  final PigStage stage;
  final DateTime? birthDate;
  final DateTime acquiredDate;
  final bool purchased;
  final double? purchasePrice;
  final String pen;
  final PigStatus status;
  final DateTime? statusDate;
  final String statusNote;
  final String? motherId;
  final String? fatherId;

  /// Base64 JPEG thumbnail (kept small so it works on every platform).
  final String? photo;
  final String notes;
  final DateTime createdAt;

  bool get isActive => status == PigStatus.active;
  String get displayName => name.isEmpty ? 'Pig $tag' : name;

  Pig copyWith({
    String? tag,
    String? name,
    Sex? sex,
    String? breed,
    PigStage? stage,
    DateTime? birthDate,
    DateTime? acquiredDate,
    bool? purchased,
    double? purchasePrice,
    String? pen,
    PigStatus? status,
    DateTime? statusDate,
    String? statusNote,
    String? motherId,
    String? fatherId,
    String? photo,
    bool clearPhoto = false,
    String? notes,
  }) => Pig(
    id: id,
    tag: tag ?? this.tag,
    name: name ?? this.name,
    sex: sex ?? this.sex,
    breed: breed ?? this.breed,
    stage: stage ?? this.stage,
    birthDate: birthDate ?? this.birthDate,
    acquiredDate: acquiredDate ?? this.acquiredDate,
    purchased: purchased ?? this.purchased,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    pen: pen ?? this.pen,
    status: status ?? this.status,
    statusDate: statusDate ?? this.statusDate,
    statusNote: statusNote ?? this.statusNote,
    motherId: motherId ?? this.motherId,
    fatherId: fatherId ?? this.fatherId,
    photo: clearPhoto ? null : (photo ?? this.photo),
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'tag': tag,
    'name': name,
    'sex': sex.name,
    'breed': breed,
    'stage': stage.name,
    'birthDate': _iso(birthDate),
    'acquiredDate': _iso(acquiredDate),
    'purchased': purchased,
    'purchasePrice': purchasePrice,
    'pen': pen,
    'status': status.name,
    'statusDate': _iso(statusDate),
    'statusNote': statusNote,
    'motherId': motherId,
    'fatherId': fatherId,
    'photo': photo,
    'notes': notes,
    'createdAt': _iso(createdAt),
  };

  factory Pig.fromJson(Map m) => Pig(
    id: _J.str(m, 'id'),
    tag: _J.str(m, 'tag', '?'),
    name: _J.str(m, 'name'),
    sex: enumByName(Sex.values, m['sex'], Sex.female),
    breed: _J.str(m, 'breed', 'Other'),
    stage: enumByName(PigStage.values, m['stage'], PigStage.grower),
    birthDate: _J.dateN(m, 'birthDate'),
    acquiredDate: _J.date(m, 'acquiredDate'),
    purchased: _J.boolean(m, 'purchased'),
    purchasePrice: _J.dblN(m, 'purchasePrice'),
    pen: _J.str(m, 'pen'),
    status: enumByName(PigStatus.values, m['status'], PigStatus.active),
    statusDate: _J.dateN(m, 'statusDate'),
    statusNote: _J.str(m, 'statusNote'),
    motherId: _J.strN(m, 'motherId'),
    fatherId: _J.strN(m, 'fatherId'),
    photo: _J.strN(m, 'photo'),
    notes: _J.str(m, 'notes'),
    createdAt: _J.date(m, 'createdAt'),
  );
}

class WeightRecord implements Entity {
  WeightRecord({required this.id, required this.pigId, required this.date, required this.kg, this.notes = ''});

  @override
  final String id;
  final String pigId;
  final DateTime date;
  final double kg;
  final String notes;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'pigId': pigId, 'date': _iso(date), 'kg': kg, 'notes': notes};

  factory WeightRecord.fromJson(Map m) =>
      WeightRecord(id: _J.str(m, 'id'), pigId: _J.str(m, 'pigId'), date: _J.date(m, 'date'), kg: _J.dbl(m, 'kg'), notes: _J.str(m, 'notes'));
}

class BreedingRecord implements Entity {
  BreedingRecord({
    required this.id,
    required this.sowId,
    this.boarId,
    this.boarName = '',
    required this.serviceDate,
    this.method = ServiceMethod.natural,
    this.status = BreedingStatus.served,
    this.farrowDate,
    this.bornAlive,
    this.stillborn,
    this.weanDate,
    this.weanedCount,
    this.notes = '',
  });

  /// Average pig gestation: 3 months, 3 weeks, 3 days.
  static const gestationDays = 114;
  static const heatCheckDays = 21;
  static const weanAfterDays = 28;

  @override
  final String id;
  final String sowId;
  final String? boarId;
  final String boarName;
  final DateTime serviceDate;
  final ServiceMethod method;
  final BreedingStatus status;
  final DateTime? farrowDate;
  final int? bornAlive;
  final int? stillborn;
  final DateTime? weanDate;
  final int? weanedCount;
  final String notes;

  DateTime get expectedFarrowing => serviceDate.add(const Duration(days: gestationDays));
  DateTime get heatCheckDate => serviceDate.add(const Duration(days: heatCheckDays));
  DateTime? get expectedWeaning => farrowDate?.add(const Duration(days: weanAfterDays));
  int get daysPregnant => DateTime.now().difference(serviceDate).inDays;
  double get gestationProgress => (daysPregnant / gestationDays).clamp(0, 1).toDouble();

  BreedingRecord copyWith({
    String? boarId,
    String? boarName,
    DateTime? serviceDate,
    ServiceMethod? method,
    BreedingStatus? status,
    DateTime? farrowDate,
    int? bornAlive,
    int? stillborn,
    DateTime? weanDate,
    int? weanedCount,
    String? notes,
  }) => BreedingRecord(
    id: id,
    sowId: sowId,
    boarId: boarId ?? this.boarId,
    boarName: boarName ?? this.boarName,
    serviceDate: serviceDate ?? this.serviceDate,
    method: method ?? this.method,
    status: status ?? this.status,
    farrowDate: farrowDate ?? this.farrowDate,
    bornAlive: bornAlive ?? this.bornAlive,
    stillborn: stillborn ?? this.stillborn,
    weanDate: weanDate ?? this.weanDate,
    weanedCount: weanedCount ?? this.weanedCount,
    notes: notes ?? this.notes,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'sowId': sowId,
    'boarId': boarId,
    'boarName': boarName,
    'serviceDate': _iso(serviceDate),
    'method': method.name,
    'status': status.name,
    'farrowDate': _iso(farrowDate),
    'bornAlive': bornAlive,
    'stillborn': stillborn,
    'weanDate': _iso(weanDate),
    'weanedCount': weanedCount,
    'notes': notes,
  };

  factory BreedingRecord.fromJson(Map m) => BreedingRecord(
    id: _J.str(m, 'id'),
    sowId: _J.str(m, 'sowId'),
    boarId: _J.strN(m, 'boarId'),
    boarName: _J.str(m, 'boarName'),
    serviceDate: _J.date(m, 'serviceDate'),
    method: enumByName(ServiceMethod.values, m['method'], ServiceMethod.natural),
    status: enumByName(BreedingStatus.values, m['status'], BreedingStatus.served),
    farrowDate: _J.dateN(m, 'farrowDate'),
    bornAlive: m['bornAlive'] == null ? null : _J.integer(m, 'bornAlive'),
    stillborn: m['stillborn'] == null ? null : _J.integer(m, 'stillborn'),
    weanDate: _J.dateN(m, 'weanDate'),
    weanedCount: m['weanedCount'] == null ? null : _J.integer(m, 'weanedCount'),
    notes: _J.str(m, 'notes'),
  );
}

// ───────────────────────── Poultry ─────────────────────────

class Flock implements Entity {
  Flock({
    required this.id,
    required this.name,
    required this.type,
    required this.breed,
    required this.initialCount,
    required this.startDate,
    this.ageAtStartWeeks = 0,
    this.house = '',
    this.costPerBird,
    this.status = FlockStatus.active,
    this.notes = '',
    required this.createdAt,
  });

  @override
  final String id;
  final String name;
  final BirdType type;
  final String breed;
  final int initialCount;
  final DateTime startDate;
  final int ageAtStartWeeks;
  final String house;
  final double? costPerBird;
  final FlockStatus status;
  final String notes;
  final DateTime createdAt;

  bool get isActive => status == FlockStatus.active;

  /// Age today in weeks, counting the age the birds came in at.
  int get ageWeeks => ageAtStartWeeks + DateTime.now().difference(startDate).inDays ~/ 7;
  int get ageDays => ageAtStartWeeks * 7 + DateTime.now().difference(startDate).inDays;

  Flock copyWith({
    String? name,
    BirdType? type,
    String? breed,
    int? initialCount,
    DateTime? startDate,
    int? ageAtStartWeeks,
    String? house,
    double? costPerBird,
    FlockStatus? status,
    String? notes,
  }) => Flock(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    breed: breed ?? this.breed,
    initialCount: initialCount ?? this.initialCount,
    startDate: startDate ?? this.startDate,
    ageAtStartWeeks: ageAtStartWeeks ?? this.ageAtStartWeeks,
    house: house ?? this.house,
    costPerBird: costPerBird ?? this.costPerBird,
    status: status ?? this.status,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'breed': breed,
    'initialCount': initialCount,
    'startDate': _iso(startDate),
    'ageAtStartWeeks': ageAtStartWeeks,
    'house': house,
    'costPerBird': costPerBird,
    'status': status.name,
    'notes': notes,
    'createdAt': _iso(createdAt),
  };

  factory Flock.fromJson(Map m) => Flock(
    id: _J.str(m, 'id'),
    name: _J.str(m, 'name', 'Flock'),
    type: enumByName(BirdType.values, m['type'], BirdType.layers),
    breed: _J.str(m, 'breed', 'Other'),
    initialCount: _J.integer(m, 'initialCount'),
    startDate: _J.date(m, 'startDate'),
    ageAtStartWeeks: _J.integer(m, 'ageAtStartWeeks'),
    house: _J.str(m, 'house'),
    costPerBird: _J.dblN(m, 'costPerBird'),
    status: enumByName(FlockStatus.values, m['status'], FlockStatus.active),
    notes: _J.str(m, 'notes'),
    createdAt: _J.date(m, 'createdAt'),
  );
}

class EggRecord implements Entity {
  EggRecord({required this.id, required this.flockId, required this.date, required this.collected, this.broken = 0, this.notes = ''});

  @override
  final String id;
  final String flockId;
  final DateTime date;
  final int collected;
  final int broken;
  final String notes;

  int get good => (collected - broken).clamp(0, collected);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'flockId': flockId, 'date': _iso(date), 'collected': collected, 'broken': broken, 'notes': notes};

  factory EggRecord.fromJson(Map m) => EggRecord(
    id: _J.str(m, 'id'),
    flockId: _J.str(m, 'flockId'),
    date: _J.date(m, 'date'),
    collected: _J.integer(m, 'collected'),
    broken: _J.integer(m, 'broken'),
    notes: _J.str(m, 'notes'),
  );
}

class MortalityRecord implements Entity {
  MortalityRecord({required this.id, required this.flockId, required this.date, required this.count, required this.cause, this.notes = ''});

  @override
  final String id;
  final String flockId;
  final DateTime date;
  final int count;
  final String cause;
  final String notes;

  @override
  Map<String, dynamic> toJson() => {'id': id, 'flockId': flockId, 'date': _iso(date), 'count': count, 'cause': cause, 'notes': notes};

  factory MortalityRecord.fromJson(Map m) => MortalityRecord(
    id: _J.str(m, 'id'),
    flockId: _J.str(m, 'flockId'),
    date: _J.date(m, 'date'),
    count: _J.integer(m, 'count'),
    cause: _J.str(m, 'cause', 'Unknown'),
    notes: _J.str(m, 'notes'),
  );
}

// ───────────────────────── Health ─────────────────────────

class HealthRecord implements Entity {
  HealthRecord({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.date,
    required this.type,
    required this.product,
    this.dose = '',
    this.cost = 0,
    this.administeredBy = '',
    this.nextDue,
    this.nextDoneAt,
    this.expenseId,
    this.notes = '',
  });

  @override
  final String id;
  final TargetType targetType;
  final String targetId;
  final DateTime date;
  final HealthType type;
  final String product;
  final String dose;
  final double cost;
  final String administeredBy;
  final DateTime? nextDue;

  /// Set when the follow-up has been handled, so the reminder disappears.
  final DateTime? nextDoneAt;
  final String? expenseId;
  final String notes;

  bool get hasOpenFollowUp => nextDue != null && nextDoneAt == null;

  HealthRecord copyWith({DateTime? nextDoneAt, String? expenseId}) => HealthRecord(
    id: id,
    targetType: targetType,
    targetId: targetId,
    date: date,
    type: type,
    product: product,
    dose: dose,
    cost: cost,
    administeredBy: administeredBy,
    nextDue: nextDue,
    nextDoneAt: nextDoneAt ?? this.nextDoneAt,
    expenseId: expenseId ?? this.expenseId,
    notes: notes,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'targetType': targetType.name,
    'targetId': targetId,
    'date': _iso(date),
    'type': type.name,
    'product': product,
    'dose': dose,
    'cost': cost,
    'administeredBy': administeredBy,
    'nextDue': _iso(nextDue),
    'nextDoneAt': _iso(nextDoneAt),
    'expenseId': expenseId,
    'notes': notes,
  };

  factory HealthRecord.fromJson(Map m) => HealthRecord(
    id: _J.str(m, 'id'),
    targetType: enumByName(TargetType.values, m['targetType'], TargetType.pig),
    targetId: _J.str(m, 'targetId'),
    date: _J.date(m, 'date'),
    type: enumByName(HealthType.values, m['type'], HealthType.treatment),
    product: _J.str(m, 'product'),
    dose: _J.str(m, 'dose'),
    cost: _J.dbl(m, 'cost'),
    administeredBy: _J.str(m, 'administeredBy'),
    nextDue: _J.dateN(m, 'nextDue'),
    nextDoneAt: _J.dateN(m, 'nextDoneAt'),
    expenseId: _J.strN(m, 'expenseId'),
    notes: _J.str(m, 'notes'),
  );
}

// ───────────────────────── Sales ─────────────────────────

class Payment {
  Payment({required this.date, required this.amount, required this.method, this.reference = ''});

  final DateTime date;
  final double amount;
  final PaymentMethod method;
  final String reference;

  Map<String, dynamic> toJson() => {'date': _iso(date), 'amount': amount, 'method': method.name, 'reference': reference};

  factory Payment.fromJson(Map m) => Payment(
    date: _J.date(m, 'date'),
    amount: _J.dbl(m, 'amount'),
    method: enumByName(PaymentMethod.values, m['method'], PaymentMethod.cash),
    reference: _J.str(m, 'reference'),
  );
}

class Sale implements Entity {
  Sale({
    required this.id,
    required this.receiptNo,
    required this.date,
    required this.product,
    required this.quantity,
    required this.unitPrice,
    this.eggUnit = EggUnit.tray,
    this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    this.payments = const [],
    this.flockId,
    this.pigIds = const [],
    this.weightKg,
    this.notes = '',
    required this.createdAt,
  });

  @override
  final String id;
  final int receiptNo;
  final DateTime date;
  final Product product;
  final double quantity;
  final double unitPrice;
  final EggUnit eggUnit;
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final List<Payment> payments;
  final String? flockId;
  final List<String> pigIds;
  final double? weightKg;
  final String notes;
  final DateTime createdAt;

  double get total => quantity * unitPrice;
  double get paid => payments.fold(0, (s, p) => s + p.amount);
  double get balance => (total - paid) < 0.005 ? 0 : total - paid;
  PaymentStatus get paymentStatus => balance <= 0 ? PaymentStatus.paid : (paid > 0 ? PaymentStatus.partial : PaymentStatus.unpaid);
  PaymentMethod get mainMethod => payments.isEmpty ? PaymentMethod.credit : payments.first.method;
  String get receiptLabel => 'SH-${receiptNo.toString().padLeft(5, '0')}';

  String get unitLabel => product == Product.eggs ? (eggUnit == EggUnit.tray ? 'tray' : 'egg') : product.unit;

  String get quantityLabel {
    final q = quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toStringAsFixed(1);
    final u = unitLabel;
    return '$q ${quantity == 1 ? u : '${u}s'}';
  }

  /// Eggs taken out of stock by this sale.
  int eggsCount(int perTray) => product == Product.eggs ? (quantity * (eggUnit == EggUnit.tray ? perTray : 1)).round() : 0;

  Sale copyWith({List<Payment>? payments, String? notes, String? customerName, String? customerPhone, String? customerId}) => Sale(
    id: id,
    receiptNo: receiptNo,
    date: date,
    product: product,
    quantity: quantity,
    unitPrice: unitPrice,
    eggUnit: eggUnit,
    customerId: customerId ?? this.customerId,
    customerName: customerName ?? this.customerName,
    customerPhone: customerPhone ?? this.customerPhone,
    payments: payments ?? this.payments,
    flockId: flockId,
    pigIds: pigIds,
    weightKg: weightKg,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'receiptNo': receiptNo,
    'date': _iso(date),
    'product': product.name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'eggUnit': eggUnit.name,
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'payments': payments.map((p) => p.toJson()).toList(),
    'flockId': flockId,
    'pigIds': pigIds,
    'weightKg': weightKg,
    'notes': notes,
    'createdAt': _iso(createdAt),
  };

  factory Sale.fromJson(Map m) => Sale(
    id: _J.str(m, 'id'),
    receiptNo: _J.integer(m, 'receiptNo', 1),
    date: _J.date(m, 'date'),
    product: enumByName(Product.values, m['product'], Product.eggs),
    quantity: _J.dbl(m, 'quantity'),
    unitPrice: _J.dbl(m, 'unitPrice'),
    eggUnit: enumByName(EggUnit.values, m['eggUnit'], EggUnit.tray),
    customerId: _J.strN(m, 'customerId'),
    customerName: _J.str(m, 'customerName'),
    customerPhone: _J.str(m, 'customerPhone'),
    payments: (m['payments'] is List) ? (m['payments'] as List).whereType<Map>().map(Payment.fromJson).toList() : const [],
    flockId: _J.strN(m, 'flockId'),
    pigIds: _J.strings(m, 'pigIds'),
    weightKg: _J.dblN(m, 'weightKg'),
    notes: _J.str(m, 'notes'),
    createdAt: _J.date(m, 'createdAt'),
  );
}

class Customer implements Entity {
  Customer({required this.id, required this.name, this.phone = '', this.location = '', this.notes = '', required this.createdAt});

  @override
  final String id;
  final String name;
  final String phone;
  final String location;
  final String notes;
  final DateTime createdAt;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.length == 1 ? parts.first[0].toUpperCase() : (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Customer copyWith({String? name, String? phone, String? location, String? notes}) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    location: location ?? this.location,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );

  @override
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'location': location, 'notes': notes, 'createdAt': _iso(createdAt)};

  factory Customer.fromJson(Map m) => Customer(
    id: _J.str(m, 'id'),
    name: _J.str(m, 'name', 'Customer'),
    phone: _J.str(m, 'phone'),
    location: _J.str(m, 'location'),
    notes: _J.str(m, 'notes'),
    createdAt: _J.date(m, 'createdAt'),
  );
}

// ───────────────────────── Money out & stock ─────────────────────────

class Expense implements Entity {
  Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    required this.description,
    this.method = PaymentMethod.cash,
    this.linkedId,
    this.notes = '',
  });

  @override
  final String id;
  final DateTime date;
  final ExpenseCategory category;
  final double amount;
  final String description;
  final PaymentMethod method;

  /// Set when the expense was created automatically (stock purchase, vet visit).
  final String? linkedId;
  final String notes;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': _iso(date),
    'category': category.name,
    'amount': amount,
    'description': description,
    'method': method.name,
    'linkedId': linkedId,
    'notes': notes,
  };

  factory Expense.fromJson(Map m) => Expense(
    id: _J.str(m, 'id'),
    date: _J.date(m, 'date'),
    category: enumByName(ExpenseCategory.values, m['category'], ExpenseCategory.other),
    amount: _J.dbl(m, 'amount'),
    description: _J.str(m, 'description'),
    method: enumByName(PaymentMethod.values, m['method'], PaymentMethod.cash),
    linkedId: _J.strN(m, 'linkedId'),
    notes: _J.str(m, 'notes'),
  );
}

class InventoryItem implements Entity {
  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.lowStockLevel = 0,
    this.unitCost,
    this.expiryDate,
    this.supplier = '',
    required this.createdAt,
  });

  @override
  final String id;
  final String name;
  final ItemCategory category;
  final String unit;
  final double lowStockLevel;
  final double? unitCost;
  final DateTime? expiryDate;
  final String supplier;
  final DateTime createdAt;

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get expiresSoon => expiryDate != null && !isExpired && expiryDate!.difference(DateTime.now()).inDays <= 30;

  InventoryItem copyWith({
    String? name,
    ItemCategory? category,
    String? unit,
    double? lowStockLevel,
    double? unitCost,
    DateTime? expiryDate,
    String? supplier,
  }) => InventoryItem(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    unit: unit ?? this.unit,
    lowStockLevel: lowStockLevel ?? this.lowStockLevel,
    unitCost: unitCost ?? this.unitCost,
    expiryDate: expiryDate ?? this.expiryDate,
    supplier: supplier ?? this.supplier,
    createdAt: createdAt,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'unit': unit,
    'lowStockLevel': lowStockLevel,
    'unitCost': unitCost,
    'expiryDate': _iso(expiryDate),
    'supplier': supplier,
    'createdAt': _iso(createdAt),
  };

  factory InventoryItem.fromJson(Map m) => InventoryItem(
    id: _J.str(m, 'id'),
    name: _J.str(m, 'name', 'Item'),
    category: enumByName(ItemCategory.values, m['category'], ItemCategory.feed),
    unit: _J.str(m, 'unit', 'kg'),
    lowStockLevel: _J.dbl(m, 'lowStockLevel'),
    unitCost: _J.dblN(m, 'unitCost'),
    expiryDate: _J.dateN(m, 'expiryDate'),
    supplier: _J.str(m, 'supplier'),
    createdAt: _J.date(m, 'createdAt'),
  );
}

class StockMovement implements Entity {
  StockMovement({
    required this.id,
    required this.itemId,
    required this.date,
    required this.type,
    required this.quantity,
    this.totalCost,
    this.targetType,
    this.targetId,
    this.expenseId,
    this.notes = '',
  });

  @override
  final String id;
  final String itemId;
  final DateTime date;
  final MovementType type;
  final double quantity;
  final double? totalCost;
  final TargetType? targetType;
  final String? targetId;
  final String? expenseId;
  final String notes;

  double get signed => type == MovementType.stockIn ? quantity : -quantity;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'date': _iso(date),
    'type': type.name,
    'quantity': quantity,
    'totalCost': totalCost,
    'targetType': targetType?.name,
    'targetId': targetId,
    'expenseId': expenseId,
    'notes': notes,
  };

  factory StockMovement.fromJson(Map m) => StockMovement(
    id: _J.str(m, 'id'),
    itemId: _J.str(m, 'itemId'),
    date: _J.date(m, 'date'),
    type: enumByName(MovementType.values, m['type'], MovementType.stockIn),
    quantity: _J.dbl(m, 'quantity'),
    totalCost: _J.dblN(m, 'totalCost'),
    targetType: m['targetType'] == null ? null : enumByName(TargetType.values, m['targetType'], TargetType.flock),
    targetId: _J.strN(m, 'targetId'),
    expenseId: _J.strN(m, 'expenseId'),
    notes: _J.str(m, 'notes'),
  );
}

// ───────────────────────── Tasks ─────────────────────────

class FarmTask implements Entity {
  FarmTask({
    required this.id,
    required this.title,
    required this.dueDate,
    this.notes = '',
    this.priority = TaskPriority.normal,
    this.done = false,
    this.doneAt,
    this.repeatDaily = false,
    required this.createdAt,
  });

  @override
  final String id;
  final String title;
  final DateTime dueDate;
  final String notes;
  final TaskPriority priority;
  final bool done;
  final DateTime? doneAt;

  /// Daily chores (feeding, water) come back every day.
  final bool repeatDaily;
  final DateTime createdAt;

  bool doneOn(DateTime day) => repeatDaily ? (doneAt != null && doneAt!.year == day.year && doneAt!.month == day.month && doneAt!.day == day.day) : done;

  FarmTask copyWith({
    String? title,
    DateTime? dueDate,
    String? notes,
    TaskPriority? priority,
    bool? done,
    DateTime? doneAt,
    bool clearDoneAt = false,
    bool? repeatDaily,
  }) => FarmTask(
    id: id,
    title: title ?? this.title,
    dueDate: dueDate ?? this.dueDate,
    notes: notes ?? this.notes,
    priority: priority ?? this.priority,
    done: done ?? this.done,
    doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
    repeatDaily: repeatDaily ?? this.repeatDaily,
    createdAt: createdAt,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dueDate': _iso(dueDate),
    'notes': notes,
    'priority': priority.name,
    'done': done,
    'doneAt': _iso(doneAt),
    'repeatDaily': repeatDaily,
    'createdAt': _iso(createdAt),
  };

  factory FarmTask.fromJson(Map m) => FarmTask(
    id: _J.str(m, 'id'),
    title: _J.str(m, 'title', 'Task'),
    dueDate: _J.date(m, 'dueDate'),
    notes: _J.str(m, 'notes'),
    priority: enumByName(TaskPriority.values, m['priority'], TaskPriority.normal),
    done: _J.boolean(m, 'done'),
    doneAt: _J.dateN(m, 'doneAt'),
    repeatDaily: _J.boolean(m, 'repeatDaily'),
    createdAt: _J.date(m, 'createdAt'),
  );
}
