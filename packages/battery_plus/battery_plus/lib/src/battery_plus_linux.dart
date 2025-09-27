import 'dart:async';

import 'package:battery_plus_platform_interface/battery_plus_platform_interface.dart';
import 'package:meta/meta.dart';
import 'package:upower/upower.dart';

extension _ToBatteryState on UPowerDeviceState {
  BatteryState toBatteryState() {
    switch (this) {
      case UPowerDeviceState.charging:
        return BatteryState.charging;

      case UPowerDeviceState.discharging:
      case UPowerDeviceState.pendingDischarge:
        return BatteryState.discharging;

      case UPowerDeviceState.fullyCharged:
        return BatteryState.full;

      case UPowerDeviceState.pendingCharge:
        return BatteryState.connectedNotCharging;

      default:
        return BatteryState.unknown;
    }
  }
}

///
@visibleForTesting
typedef UPowerClientFactory = UPowerClient Function();

/// The Linux implementation of BatteryPlatform.
class BatteryPlusLinuxPlugin extends BatteryPlatform {
  /// Register this dart class as the platform implementation for linux
  static void registerWith() {
    BatteryPlatform.instance = BatteryPlusLinuxPlugin();
  }

  /// Returns the current battery level in percent.
  @override
  Future<int> get batteryLevel {
    final client = createClient();
    return client
        .connect()
        .then((_) => client.displayDevice.percentage.round())
        .whenComplete(() => client.close());
  }

  /// Returns the current battery state.
  @override
  Future<BatteryState> get batteryState {
    final client = createClient();
    return client
        .connect()
        .then((_) => client.displayDevice.state.toBatteryState())
        .whenComplete(() => client.close);
  }

  /// Fires whenever the battery state changes.
  @override
  Stream<BatteryChangeEvent> get onBatteryStateChanged {
    _stateController ??= StreamController<BatteryChangeEvent>.broadcast(
      onListen: _startListenState,
      onCancel: _stopListenState,
    );
    return _stateController!.stream.asBroadcastStream();
  }

  UPowerClient? _stateClient;
  StreamController<BatteryChangeEvent>? _stateController;

  @visibleForTesting
  // ignore: public_member_api_docs, prefer_function_declarations_over_variables
  UPowerClientFactory createClient = () => UPowerClient();

  void _addBatteryChangeEvent() {
    final device = _stateClient!.displayDevice;
    _stateController!.add(
      BatteryChangeEvent(
        state: device.state.toBatteryState(),
        level: device.percentage.round(),
        isInBatterySaveMode: device.powerSupply,
        capacity: (device.energyFull * 1000).round(),
        chargeTimeRemaining: device.timeToFull.inSeconds,
        currentAverage: -1,
        currentNow: (device.energyRate * 1000).round(),
        health: device.health.toString(),
        pluggedStatus: device.state.toBatteryState().toString(),
        presence: device.isPresent.toString(),
        scale: 100,
        remainingEnergy: (device.energy * 1000).round(),
        technology: device.technology.toString(),
        temperature: device.temperature,
        voltage: (device.voltage * 1000).round(),
      ),
    );
  }

  Future<void> _startListenState() async {
    _stateClient ??= createClient();
    await _stateClient!.connect().then((_) => _addBatteryChangeEvent());
    _stateClient!.displayDevice.propertiesChanged.listen((properties) {
      if (properties.contains('State') ||
          properties.contains('Percentage') ||
          properties.contains('PowerSupply')) {
        _addBatteryChangeEvent();
      }
    });
  }

  void _stopListenState() {
    _stateController?.close();
    _stateClient?.close();
    _stateClient = null;
  }
}
