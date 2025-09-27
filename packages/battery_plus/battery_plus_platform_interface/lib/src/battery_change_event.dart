// Copyright 2024 The Flutter Community Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'enums.dart';

/// Represents a change in the battery state, including the new state,
/// current battery level, and whether the device is in battery save mode.
class BatteryChangeEvent {
  /// Constructs a BatteryChangeEvent.
  BatteryChangeEvent({
    required this.state,
    required this.level,
    required this.isInBatterySaveMode,
    this.capacity,
    this.chargeTimeRemaining,
    this.currentAverage,
    this.currentNow,
    this.health,
    this.pluggedStatus,
    this.presence,
    this.scale,
    this.remainingEnergy,
    this.technology,
    this.temperature,
    this.voltage,
  });

  /// The new battery state.
  final BatteryState state;

  /// The current battery level in percent.
  final int level;

  /// Whether the device is in battery save mode.
  final bool isInBatterySaveMode;

  /// The battery capacity in mAh.
  final int? capacity;

  /// The remaining time until the battery is fully charged.
  final int? chargeTimeRemaining;

  /// The average battery current in microamperes.
  final int? currentAverage;

  /// The instantaneous battery current in microamperes.
  final int? currentNow;

  /// The battery health.
  final String? health;

  /// The plugged status.
  final String? pluggedStatus;

  /// The battery presence.
  final String? presence;

  /// The battery scale.
  final int? scale;

  /// The remaining energy in microampere-hours.
  final int? remainingEnergy;

  /// The battery technology.
  final String? technology;

  /// The battery temperature in tenths of a degree Celsius.
  final double? temperature;

  /// The battery voltage in millivolts.
  final int? voltage;
}
