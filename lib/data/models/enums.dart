import 'package:flutter/material.dart';

import '../../core/constants/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/phosphor.dart';

/// Parses an enum by name, falling back when stored data is old or corrupt.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

// ───────────────────────── Pigs ─────────────────────────

enum Sex {
  female('Female', PhosphorIconsBold.genderFemale),
  male('Male', PhosphorIconsBold.genderMale);

  const Sex(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum PigStage {
  piglet('Piglet', 'Birth – 8 wks'),
  weaner('Weaner', '8 – 12 wks'),
  grower('Grower', '12 – 20 wks'),
  finisher('Finisher', '20 wks – market'),
  gilt('Gilt', 'Young female for breeding'),
  sow('Sow', 'Breeding female'),
  boar('Boar', 'Breeding male');

  const PigStage(this.label, this.hint);
  final String label;
  final String hint;

  bool get isBreeder => this == sow || this == gilt || this == boar;
  bool get isYoung => this == piglet || this == weaner;
}

enum PigStatus {
  active('Active', AppColors.success),
  sold('Sold', AppColors.info),
  dead('Dead', AppColors.danger);

  const PigStatus(this.label, this.color);
  final String label;
  final Color color;
}

const pigBreeds = ['Large White', 'Landrace', 'Duroc', 'Hampshire', 'Pietrain', 'Camborough', 'Large White × Landrace', 'Local / Cross', 'Other'];

enum BreedingStatus {
  served('Served', AppColors.info),
  pregnant('Pregnant', AppColors.pinkDeep),
  farrowed('Farrowed', AppColors.success),
  weaned('Weaned', AppColors.forest),
  failed('Returned to heat', AppColors.warning);

  const BreedingStatus(this.label, this.color);
  final String label;
  final Color color;
  bool get isOpen => this == served || this == pregnant;
}

enum ServiceMethod {
  natural('Natural'),
  ai('A.I.');

  const ServiceMethod(this.label);
  final String label;
}

// ───────────────────────── Poultry ─────────────────────────

enum BirdType {
  layers('Layers', 'Kept for eggs', Assets.catLayers, AppColors.amber),
  broilers('Broilers', 'Kept for meat', Assets.catBroilers, AppColors.lime),
  kienyeji('Kienyeji', 'Improved indigenous', Assets.catKienyeji, AppColors.pinkDeep);

  const BirdType(this.label, this.hint, this.image, this.color);
  final String label;
  final String hint;
  final String image;
  final Color color;

  bool get laysEggs => this != broilers;
}

const birdBreeds = {
  BirdType.layers: ['ISA Brown', 'Hy-Line Brown', 'Lohmann Brown', 'Bovans', 'Other'],
  BirdType.broilers: ['Cobb 500', 'Ross 308', 'Arbor Acres', 'Hubbard', 'Other'],
  BirdType.kienyeji: ['Kuroiler', 'Kenbro', 'Rainbow Rooster', 'Sasso', 'Pure local', 'Other'],
};

enum FlockStatus {
  active('Active', AppColors.success),
  closed('Closed', AppColors.inkMuted);

  const FlockStatus(this.label, this.color);
  final String label;
  final Color color;
}

const mortalityCauses = ['Disease', 'Predator', 'Injury', 'Heat stress', 'Cold / brooding', 'Unknown', 'Culled', 'Other'];

// ───────────────────────── Health ─────────────────────────

enum HealthType {
  vaccination('Vaccination', PhosphorIconsBold.syringe, AppColors.info),
  treatment('Treatment', PhosphorIconsBold.pill, AppColors.pinkDeep),
  deworming('Deworming', PhosphorIconsBold.bug, AppColors.warning),
  vitamins('Vitamins / Boosters', PhosphorIconsBold.drop, AppColors.lime),
  checkup('Check-up', PhosphorIconsBold.stethoscope, AppColors.forest);

  const HealthType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

enum TargetType { pig, flock }

// ───────────────────────── Sales ─────────────────────────

enum Product {
  eggs('Eggs', 'tray', Assets.prodEggTray, AppColors.amber),
  liveChicken('Live chicken', 'bird', Assets.prodLiveChicken, AppColors.pinkDeep),
  dressedChicken('Dressed chicken', 'bird', Assets.prodDressedChicken, AppColors.warning),
  pig('Pig', 'pig', Assets.prodPig, AppColors.pink),
  piglet('Piglet', 'piglet', Assets.prodPiglet, AppColors.pinkDeep),
  manure('Manure', 'bag', Assets.prodManure, AppColors.forest);

  const Product(this.label, this.unit, this.image, this.color);
  final String label;
  final String unit;
  final String image;
  final Color color;

  /// Fits under small product chips.
  String get short => switch (this) {
    liveChicken => 'Live bird',
    dressedChicken => 'Dressed',
    _ => label,
  };

  bool get fromFlock => this == liveChicken || this == dressedChicken;
  bool get fromPigs => this == pig || this == piglet;
}

enum EggUnit {
  tray('Trays', 30),
  piece('Pieces', 1);

  const EggUnit(this.label, this.eggs);
  final String label;
  final int eggs;
}

enum PaymentMethod {
  cash('Cash', PhosphorIconsBold.money),
  mpesa('M-Pesa', PhosphorIconsBold.deviceMobile),
  bank('Bank', PhosphorIconsBold.bank),
  credit('On credit', PhosphorIconsBold.handshake);

  const PaymentMethod(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum PaymentStatus {
  paid('Paid', AppColors.success),
  partial('Partly paid', AppColors.warning),
  unpaid('Unpaid', AppColors.danger);

  const PaymentStatus(this.label, this.color);
  final String label;
  final Color color;
}

// ───────────────────────── Expenses & stock ─────────────────────────

enum ExpenseCategory {
  feed('Feed', PhosphorIconsBold.grains, AppColors.amber),
  vet('Vet & medicine', PhosphorIconsBold.firstAidKit, AppColors.info),
  labour('Labour', PhosphorIconsBold.usersThree, AppColors.forest),
  stock('Buying animals', PhosphorIconsBold.shoppingCart, AppColors.pinkDeep),
  transport('Transport', PhosphorIconsBold.truck, AppColors.warning),
  utilities('Water & power', PhosphorIconsBold.lightning, AppColors.lime),
  equipment('Equipment & repairs', PhosphorIconsBold.wrench, AppColors.inkSoft),
  other('Other', PhosphorIconsBold.dotsThreeCircle, AppColors.inkMuted);

  const ExpenseCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

enum ItemCategory {
  feed('Feed', PhosphorIconsBold.grains, AppColors.amber),
  medicine('Medicine', PhosphorIconsBold.pill, AppColors.info),
  vaccine('Vaccine', PhosphorIconsBold.syringe, AppColors.pinkDeep),
  supplies('Supplies', PhosphorIconsBold.package, AppColors.forest);

  const ItemCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

const stockUnits = ['kg', 'bags', 'litres', 'doses', 'bottles', 'pieces'];

enum MovementType { stockIn, stockOut }

// ───────────────────────── Tasks ─────────────────────────

enum TaskPriority {
  low('Low', AppColors.inkMuted),
  normal('Normal', AppColors.info),
  high('High', AppColors.danger);

  const TaskPriority(this.label, this.color);
  final String label;
  final Color color;
}
