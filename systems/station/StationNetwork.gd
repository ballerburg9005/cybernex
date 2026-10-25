extends Node
class_name StationNetwork

## A persistent, inspectable dependency graph. Devices run on authored power
## networks: AC, DC, and HV can exchange energy only via converter devices.
signal device_status_changed(device_id: String, online: bool)
signal bus_status_changed(bus_id: String, online: bool)

@export var buses: Array[PowerBusSpec] = []
@export var devices: Array[StationDeviceSpec] = []
@export_range(0.05, 10.0, 0.05) var tick_seconds: float = 0.2

var elapsed: float = 0.0
var time_seconds: float = 0.0
var bus_online: Dictionary = {}
var device_online: Dictionary = {}
var denial_reasons: Dictionary = {}
var granted_protocols: Dictionary = {}
var repaired_modules: Dictionary = {}
var conditions: Dictionary = {}
var last_available_watts: Dictionary = {}

func _process(delta: float) -> void:
    elapsed += delta
    while elapsed >= tick_seconds:
        elapsed -= tick_seconds
        time_seconds += tick_seconds
        evaluate()

func _find_device(device_id: String) -> StationDeviceSpec:
    for device in devices:
        if device != null and device.device_id == device_id:
            return device
    return null

func _find_bus(bus_id: String) -> PowerBusSpec:
    for bus in buses:
        if bus != null and bus.bus_id == bus_id:
            return bus
    return null

func grant_protocol(protocol: String, allowed: bool = true) -> void:
    granted_protocols[protocol] = allowed
    evaluate()

func set_repaired_module(module_id: String, repaired: bool = true) -> void:
    repaired_modules[module_id] = repaired
    evaluate()

func set_condition(condition_id: String, satisfied: bool) -> void:
    conditions[condition_id] = satisfied
    evaluate()

func set_bus_enabled(bus_id: String, enabled: bool) -> void:
    var bus: PowerBusSpec = _find_bus(bus_id)
    if bus != null:
        bus.powered = enabled
        evaluate()

func set_device_enabled(device_id: String, enabled: bool) -> void:
    var device: StationDeviceSpec = _find_device(device_id)
    if device != null:
        device.operator_enabled = enabled
        evaluate()

func damage_device(device_id: String) -> void:
    var device: StationDeviceSpec = _find_device(device_id)
    if device != null:
        device.intact = false
        evaluate()

func repair_device(device_id: String) -> void:
    var device: StationDeviceSpec = _find_device(device_id)
    if device != null:
        device.intact = true
        evaluate()

func evaluate() -> void:
    var available: Dictionary = {}
    var source_on: Dictionary = {}
    # Bus supply is not the same thing as a live bus: a cold secondary bus
    # is allowed to receive power from an operating converter.
    for bus in buses:
        if bus == null:
            continue
        var on: bool = bus.powered
        if bus.duty_period_seconds > 0.0:
            on = on and fposmod(time_seconds, bus.duty_period_seconds) < bus.duty_period_seconds * bus.duty_fraction
        source_on[bus.bus_id] = on
        available[bus.bus_id] = bus.capacity_watts if on else 0.0

    # Non-cyclic converter chains in explicitly authored order.
    # This stage is the ONLY way to move capacity between domains.
    for device in devices:
        if device == null or device.device_type != "converter":
            continue
        var reason: String = _precheck(device)
        if not reason.is_empty():
            _write_device_status(device.device_id, false, reason)
            continue
        if device.supply_bus == device.output_bus or not available.has(device.output_bus):
            _write_device_status(device.device_id, false, "Invalid converter secondary")
            continue
        if not available.has(device.supply_bus) or float(available[device.supply_bus]) < device.demand_watts:
            _write_device_status(device.device_id, false, "Insufficient primary power")
            continue
        available[device.supply_bus] = float(available[device.supply_bus]) - device.demand_watts
        available[device.output_bus] = float(available[device.output_bus]) + minf(
            device.conversion_capacity_watts, device.demand_watts * device.efficiency)
        _write_device_status(device.device_id, true)

    # Report resulting powered-ness after the converter stage.
    for bus in buses:
        if bus == null:
            continue
        var online: bool = float(available.get(bus.bus_id, 0.0)) > 0.0
        if bool(bus_online.get(bus.bus_id, false)) != online:
            bus_status_changed.emit(bus.bus_id, online)
        bus_online[bus.bus_id] = online

    # Consumers have fixed, deliberately authored priority. A budget shortage
    # must create brownouts rather than free energy.
    for device in devices:
        if device == null or device.device_type == "converter":
            continue
        var reason: String = _precheck(device)
        if reason.is_empty():
            for prerequisite in device.required_devices:
                if not bool(device_online.get(prerequisite, false)):
                    reason = "Dependency offline: " + prerequisite
                    break
        if reason.is_empty() and not device.requires_protocol.is_empty():
            if not bool(granted_protocols.get(device.requires_protocol, false)):
                reason = "Protocol denied: " + device.requires_protocol
        if reason.is_empty():
            for module_id in device.required_modules:
                if not bool(repaired_modules.get(module_id, false)):
                    reason = "Hardware diagnostic failed: " + module_id
                    break
        if reason.is_empty():
            for condition_id in device.required_conditions:
                if not bool(conditions.get(condition_id, false)):
                    reason = "Interlock condition unsatisfied: " + condition_id
                    break
        if reason.is_empty() and float(available.get(device.supply_bus, 0.0)) < device.demand_watts:
            reason = "Insufficient power from " + device.supply_bus
        if reason.is_empty():
            available[device.supply_bus] = float(available[device.supply_bus]) - device.demand_watts
        _write_device_status(device.device_id, reason.is_empty(), reason)
    last_available_watts = available

func _precheck(device: StationDeviceSpec) -> String:
    if not device.intact:
        return "Physical fault"
    if not device.operator_enabled:
        return "Isolated by operator"
    if device.demand_watts <= 0.0:
        return "Invalid power budget"
    return ""

func _write_device_status(device_id: String, online: bool, reason: String = "") -> void:
    denial_reasons[device_id] = reason
    if bool(device_online.get(device_id, false)) != online:
        device_status_changed.emit(device_id, online)
    device_online[device_id] = online

func snapshot() -> Dictionary:
    var power_flags: Dictionary = {}
    var device_flags: Dictionary = {}
    for bus in buses:
        if bus != null:
            power_flags[bus.bus_id] = bus.powered
    for device in devices:
        if device != null:
            device_flags[device.device_id] = {
                "intact": device.intact, "enabled": device.operator_enabled
            }
    return {
        "time": time_seconds, "buses": power_flags, "devices": device_flags,
        "protocols": granted_protocols.duplicate(true),
        "modules": repaired_modules.duplicate(true),
        "conditions": conditions.duplicate(true)
    }

func restore(data: Dictionary) -> void:
    time_seconds = maxf(0.0, float(data.get("time", 0.0)))
    var power_flags: Dictionary = data.get("buses", {})
    var device_flags: Dictionary = data.get("devices", {})
    for bus in buses:
        if bus != null and power_flags.has(bus.bus_id):
            bus.powered = bool(power_flags[bus.bus_id])
    for device in devices:
        if device != null and device_flags.has(device.device_id):
            var state: Dictionary = device_flags[device.device_id]
            device.intact = bool(state.get("intact", device.intact))
            device.operator_enabled = bool(state.get("enabled", device.operator_enabled))
    granted_protocols = data.get("protocols", {}).duplicate(true)
    repaired_modules = data.get("modules", {}).duplicate(true)
    conditions = data.get("conditions", {}).duplicate(true)
    evaluate()
