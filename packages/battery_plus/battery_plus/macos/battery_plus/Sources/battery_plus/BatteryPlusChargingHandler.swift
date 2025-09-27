import Foundation
import FlutterMacOS
import IOKit.ps

class BatteryPlusChargingHandler: NSObject, FlutterStreamHandler {

    private var context: Int = 0

    private var source: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink event: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = event
        start()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stop()
        self.eventSink = nil
        return nil
    }

    func start() {
        // If there is an added loop, we remove it before adding a new one.
        stop()

        // Gets the initial battery status
        sendBatteryChangeEvent()

        // Registers a run loop which is notified when the battery status changes
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        source = IOPSNotificationCreateRunLoopSource({ (context) in
            let _self = Unmanaged<BatteryPlusChargingHandler>.fromOpaque(UnsafeRawPointer(context!)).takeUnretainedValue()
            _self.sendBatteryChangeEvent()
        }, context).takeUnretainedValue()

        // Adds loop to source
        runLoop = RunLoop.current.getCFRunLoop()
        CFRunLoopAddSource(runLoop, source, .defaultMode)
    }

    func stop() {
        guard let runLoop = runLoop, let source = source else {
            return
        }
        CFRunLoopRemoveSource(runLoop, source, .defaultMode)
    }

    func getBatteryStatus()-> String {
        let powerSourceSnapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(powerSourceSnapshot).takeRetainedValue() as [CFTypeRef]

        // When no sources available it is highly likely a desktop, thus, connected_not_charging.
        if sources.isEmpty {
            return "connected_not_charging"
        }

        let description = IOPSGetPowerSourceDescription(powerSourceSnapshot, sources[0]).takeUnretainedValue() as! [String: AnyObject]

        if let isFullyCharged = description[kIOPSIsChargedKey] as? Bool {
            if isFullyCharged {
               return "full"
            }
        }

        let isConnected = (description[kIOPSPowerSourceStateKey] as? String)

        if let isCharging = (description[kIOPSIsChargingKey] as? Bool) {
            if isCharging {
                return "charging"
            } else if isConnected == kIOPSACPowerValue {
                return "connected_not_charging"
            } else {
                return "discharging"
            }
        }
        return "unknown"
    }

    private func getBatteryLevel()-> Int {
        let powerSourceSnapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(powerSourceSnapshot).takeRetainedValue() as Array
        if sources.isEmpty {
            return -1
        }
        let description = IOPSGetPowerSourceDescription(powerSourceSnapshot, sources[0]).takeUnretainedValue() as! [String: AnyObject]
        if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int {
            return currentCapacity;
        }
        return -1
    }

    private func isLowPowerModeEnabled()-> Bool {
        if #available(macOS 12.0, *) {
            return ProcessInfo.processInfo.isLowPowerModeEnabled
        } else {
            // Low Power Mode is not supported on macOS versions prior to 12.0
            return false
        }
    }

    private func sendBatteryChangeEvent() {
        if let sink = self.eventSink {
            let powerSourceSnapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
            let sources = IOPSCopyPowerSourcesList(powerSourceSnapshot).takeRetainedValue() as Array
            if sources.isEmpty {
                sink(FlutterError(code: "UNAVAILABLE", message: "Battery info unavailable", details: nil))
                return
            }
            let description = IOPSGetPowerSourceDescription(powerSourceSnapshot, sources[0]).takeUnretainedValue() as! [String: AnyObject]

            let status = getBatteryStatus(description: description)
            let level = getBatteryLevel(description: description)
            let saveMode = isLowPowerModeEnabled()

            var event: [String: Any] = [
                "state": status,
                "level": level,
                "isInBatterySaveMode": saveMode
            ]

            event["capacity"] = description[kIOPSMaxCapacityKey] as? Int ?? -1
            event["chargeTimeRemaining"] = description[kIOPSTimeToFullChargeKey] as? Int ?? -1
            event["currentAverage"] = -1 // Not available on macOS
            event["currentNow"] = description[kIOPSAmperageKey] as? Int ?? -1
            event["health"] = description[kIOPSHealthKey] as? String ?? "unknown"
            event["pluggedStatus"] = description[kIOPSPowerSourceStateKey] as? String ?? "unknown"
            event["presence"] = "true" // macOS devices always have a battery
            event["scale"] = 100
            event["remainingEnergy"] = -1 // Not available on macOS
            event["technology"] = "Li-ion" // Assumption
            event["temperature"] = description[kIOPSTemperatureKey] as? Double ?? -1.0
            event["voltage"] = description[kIOPSVoltageKey] as? Int ?? -1

            sink(event)
        }
    }
}
