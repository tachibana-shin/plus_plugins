// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

#import "./include/battery_plus/FPPBatteryPlusPlugin.h"

@interface FPPBatteryPlusPlugin () <FlutterStreamHandler>
@end

@implementation FPPBatteryPlusPlugin {
  FlutterEventSink _eventSink;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FPPBatteryPlusPlugin *instance = [[FPPBatteryPlusPlugin alloc] init];

  FlutterMethodChannel *channel = [FlutterMethodChannel
      methodChannelWithName:@"dev.fluttercommunity.plus/battery"
            binaryMessenger:[registrar messenger]];

  [registrar addMethodCallDelegate:instance channel:channel];
  FlutterEventChannel *chargingChannel = [FlutterEventChannel
      eventChannelWithName:@"dev.fluttercommunity.plus/charging"
           binaryMessenger:[registrar messenger]];
  [chargingChannel setStreamHandler:instance];
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result {
  if ([@"getBatteryLevel" isEqualToString:call.method]) {
    int batteryLevel = [self getBatteryLevel];
    if (batteryLevel == -1) {
      result([FlutterError errorWithCode:@"UNAVAILABLE"
                                 message:@"Battery info unavailable"
                                 details:nil]);
    } else {
      result(@(batteryLevel));
    }
  } else if ([@"getBatteryState" isEqualToString:call.method]) {
    NSString *state = [self getBatteryState];
    if (state) {
      result(state);
    } else {
      result([FlutterError errorWithCode:@"UNAVAILABLE"
                                 message:@"Charging status unavailable"
                                 details:nil]);
    }
  } else if ([@"isInBatterySaveMode" isEqualToString:call.method]) {
    result(@([[NSProcessInfo processInfo] isLowPowerModeEnabled]));
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)onBatteryDidChange:(NSNotification *)notification {
  [self sendBatteryChangeEvent];
}

- (void)sendBatteryChangeEvent {
  if (!_eventSink) return;

  NSString *batteryState = [self getBatteryState];
  int batteryLevel = [self getBatteryLevel];
  bool isInBatterySaveMode = [[NSProcessInfo processInfo] isLowPowerModeEnabled];

  if (batteryState) {
    NSDictionary *powerSourceInfo = [self getPowerSourceInfo];
    NSMutableDictionary *event = [NSMutableDictionary dictionary];
    event[@"state"] = batteryState;
    event[@"level"] = @(batteryLevel);
    event[@"isInBatterySaveMode"] = @(isInBatterySaveMode);
    event[@"capacity"] = powerSourceInfo[(__bridge NSString *)CFSTR(kIOPSMaxCapacityKey)] ?: @(-1);
    event[@"chargeTimeRemaining"] = powerSourceInfo[(__bridge NSString *)CFSTR(kIOPSTimeToFullChargeKey)] ?: @(-1);
    event[@"currentAverage"] = @(-1); // Not available on iOS
    event[@"currentNow"] = powerSourceInfo[(__bridge NSString *)CFSTR(kIOPSAmperageKey)] ?: @(-1);
    event[@"health"] = powerSourceInfo[(__bridge NSString *)CFSTR(kIOPSHealthKey)] ?: @"unknown";
    event[@"pluggedStatus"] = powerSourceInfo[(__bridge NSString *)CFSTR(kIOPSPowerSourceStateKey)] ?: @"unknown";
    event[@"presence"] = @"true"; // iOS devices always have a battery
    event[@"scale"] = @(100);
    event[@"remainingEnergy"] = @(-1); // Not available on iOS
    event[@"technology"] = @"Li-ion"; // Assumption
    event[@"temperature"] = powerSourceInfo[(__bridge NSString *)CFSTR(kIOPSTemperatureKey)] ?: @(-1);
    event[@"voltage"] = powerSourceInfo[(__bridge NSString *)CFSTR(kIOPSVoltageKey)] ?: @(-1);

    _eventSink(event);
  } else {
    _eventSink([FlutterError errorWithCode:@"UNAVAILABLE"
                                   message:@"Battery info unavailable"
                                   details:nil]);
  }
}

- (NSDictionary *)getPowerSourceInfo {
    CFTypeRef powerSourcesInfo = IOPSCopyPowerSourcesInfo();
    CFArrayRef powerSourcesList = IOPSCopyPowerSourcesList(powerSourcesInfo);

    if (CFArrayGetCount(powerSourcesList) == 0) {
        CFRelease(powerSourcesInfo);
        CFRelease(powerSourcesList);
        return @{};
    }

    CFDictionaryRef powerSource = IOPSGetPowerSourceDescription(powerSourcesInfo, CFArrayGetValueAtIndex(powerSourcesList, 0));
    NSDictionary *powerSourceInfo = (__bridge_transfer NSDictionary *)powerSource;

    CFRelease(powerSourcesInfo);
    CFRelease(powerSourcesList);

    return powerSourceInfo;
}

- (NSString *)getBatteryState {
  UIDevice *device = UIDevice.currentDevice;
  device.batteryMonitoringEnabled = YES;
  UIDeviceBatteryState state = [device batteryState];
  switch (state) {
    case UIDeviceBatteryStateUnknown:
      return @"unknown";
    case UIDeviceBatteryStateFull:
      return @"full";
    case UIDeviceBatteryStateCharging:
      return @"charging";
    case UIDeviceBatteryStateUnplugged:
      return @"discharging";
    default:
      return nil;
  }
}

- (int)getBatteryLevel {
  UIDevice *device = UIDevice.currentDevice;
  device.batteryMonitoringEnabled = YES;
  if (device.batteryState == UIDeviceBatteryStateUnknown) {
    return -1;
  } else {
    return ((int)(device.batteryLevel * 100));
  }
}

#pragma mark FlutterStreamHandler impl

- (FlutterError *)onListenWithArguments:(id)arguments
                              eventSink:(FlutterEventSink)eventSink {
  _eventSink = eventSink;
  [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
  [self sendBatteryChangeEvent];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(onBatteryDidChange:)
             name:UIDeviceBatteryStateDidChangeNotification
           object:nil];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(onBatteryDidChange:)
             name:UIDeviceBatteryLevelDidChangeNotification
           object:nil];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(onBatteryDidChange:)
             name:NSProcessInfoPowerStateDidChangeNotification
           object:nil];

  return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];
  _eventSink = nil;
  return nil;
}

@end
