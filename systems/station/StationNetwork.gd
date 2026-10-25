extends Node
class_name StationNetwork

## Small deterministic world-systems foundation. Persistent faults and
## interlocks drive signals; quests do not toggle doors independently.
signal device_status_changed(device_id: String, online: bool)
signal bus_status_changed(bus_id: String, online: bool)

@export var buses: Array[PowerBusSpec] = []
@export var devices: Array[StationDeviceSpec] = []
@export var tick_seconds: float = 0.2

var elapsed: float = 0.0
var time_seconds: float = 0.0
var bus_online: Dictionary = {}
var device_online: Dictionary = {}
var granted_protocols: Dictionary = {}

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= tick_seconds:
        time_seconds += elapsed
        elapsed = 0.0
        evaluate()

func grant_protocol(protocol: String, allowed: bool = true) -> void:
    granted_protocols[protocol] = allowed
    evaluate()

func damage_device(device_id: String) -> void:
    for device in devices:
        if device.device_id == device_id:
            device.intact = false
    evaluate()

func repair_device(device_id: String) -> void:
    for device in devices:
        if device.device_id == device_id:
            device.intact = true
    evaluate()

func evaluate() -> void:
    var available: Dictionary = {}
    var domain: Dictionary = {}
    for bus in buses:
        var on: bool = bus.powered
        if bus.duty_period_seconds > 0.0:
            on = on and fposmod(time_seconds, bus.duty_period_seconds) < bus.duty_period_seconds * bus.duty_fraction
        domain[bus.bus_id] = bus.domain
        available[bus.bus_id] = bus.capacity_watts if on else 0.0
        if bool(bus_online.get(bus.bus_id, false)) != on:
            bus_status_changed.emit(bus.bus_id, on)
        bus_online[bus.bus_id] = on

    # Converter devices are the only sanctioned bridge between power domains.
    # Evaluate converters before consumers; cyclic converter chains are prohibited.
    for device in devices:
        if device.device_type != "converter":
            continue
        var enabled: bool = device.intact and device.operator_enabled
        if device.supply_bus == device.output_bus or not available.has(device.output_bus):
            enabled = false
        if enabled and float(available.get(device.supply_bus, 0.0)) >= device.demand_watts:
            available[device.supply_bus] -= device.demand_watts
            available[device.output_bus] += minf(device.conversion_capacity_watts, device.demand_watts * device.efficiency)
        else:
            enabled = false
        _write_device_status(device.device_id, enabled)
    # Dependencies, power budgets and protocol authorization all matter.
    # Sort resources in the Inspector to explicitly choose load priority.
    for device in devices:
        if device.device_type == "converter":
            continue
        var enabled: bool = device.intact and device.operator_enabled
        for dependency in device.required_devices:
            enabled = enabled and bool(device_online.get(dependency, false))
        if not device.requires_protocol.is_empty():
            enabled = enabled and bool(granted_protocols.get(device.requires_protocol, false))
        if enabled and float(available.get(device.supply_bus, 0.0)) >= device.demand_watts:
            available[device.supply_bus] -= device.demand_watts
        else:
            enabled = false
        _write_device_status(device.device_id, enabled)

func _write_device_status(device_id: String, online: bool) -> void:
    if bool(device_online.get(device_id, false)) != online:
        device_status_changed.emit(device_id, online)
    device_online[device_id] = online
