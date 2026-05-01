import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MeasurementUnit { metric, imperial }

const _kUnitsKey = 'app_measurement_unit';

class UnitsNotifier extends StateNotifier<MeasurementUnit> {
  UnitsNotifier() : super(MeasurementUnit.metric) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kUnitsKey) == 'imperial'
        ? MeasurementUnit.imperial
        : MeasurementUnit.metric;
  }

  Future<void> setUnit(MeasurementUnit unit) async {
    state = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kUnitsKey, unit == MeasurementUnit.imperial ? 'imperial' : 'metric');
  }

  String get label => state == MeasurementUnit.imperial ? 'Imperial' : 'Metric';
}

final unitsProvider =
    StateNotifierProvider<UnitsNotifier, MeasurementUnit>((ref) {
  return UnitsNotifier();
});

// Helpers — convert stored metric values to the current unit system.
extension MeasurementUnitX on MeasurementUnit {
  String formatHeight(double? cm) {
    if (cm == null) return '—';
    if (this == MeasurementUnit.imperial) {
      final int totalIn = (cm / 2.54).round();
      final int ft = totalIn ~/ 12;
      final int inches = totalIn % 12;
      return "$ft'$inches\"";
    }
    return '${cm.toStringAsFixed(0)} cm';
  }

  String formatWeight(double? kg) {
    if (kg == null) return '—';
    if (this == MeasurementUnit.imperial) {
      return '${(kg * 2.20462).toStringAsFixed(0)} lbs';
    }
    return '${kg.toStringAsFixed(0)} kg';
  }
}
