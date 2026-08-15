import 'package:flutter/material.dart';

import '../../models/vehicle.dart' as vehicle_model;

/// Ana ekrandaki araç kartı için önceden formatlanmış (görüntüye hazır)
/// alanları taşıyan görünüm modeli. Önceden `home_screen.dart` içinde
/// tanımlıydı; davranış değişmeden buraya taşındı.
class DemoVehicle {
  final vehicle_model.Vehicle source;
  final String name;
  final String plate;
  final String kilometer;
  final IconData icon;
  final List<Color> colors;
  final String monthlyExpense;
  final String totalExpense;
  final String fuelCost;
  final String runningCost;
  final String consumption;
  final String? petrolConsumption;
  final String? lpgConsumption;
  final String totalCostPerKm;
  final String? localImagePath;
  final String? localStickerPath;

  const DemoVehicle({
    required this.source,
    required this.name,
    required this.plate,
    required this.kilometer,
    required this.icon,
    required this.colors,
    required this.monthlyExpense,
    required this.totalExpense,
    required this.fuelCost,
    required this.runningCost,
    required this.consumption,
    this.petrolConsumption,
    this.lpgConsumption,
    required this.totalCostPerKm,
    this.localImagePath,
    this.localStickerPath,
  });
}
