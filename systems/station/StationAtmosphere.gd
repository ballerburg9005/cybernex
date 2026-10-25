extends Node
class_name StationAtmosphere

## Single compartment model; realistic causality but deliberately not CFD.
## Fractions are fractions of total atmosphere. Gas displacement reduces O2;
## ventilation consumes available power through an external station device.
signal atmosphere_changed
@export_range(0.0, 1.0, 0.001) var initial_oxygen_fraction: float = 0.209
@export_range(0.0, 1.0, 0.001) var initial_hazard_fraction: float = 0.0
@export_range(0.0, 0.5, 0.0001) var baseline_leak_rate: float = 0.0001
@export_range(0.0, 0.5, 0.0001) var fan_exchange_per_second: float = 0.04
@export var ventilation_device_id: String = "ventilation_drive"
@export var station: StationNetwork
var oxygen_fraction: float = 0.209
var hazard_fraction: float = 0.0
var gas_injection_per_second: float = 0.0
var simulated_seconds: float = 0.0

func _ready() -> void:
    oxygen_fraction = initial_oxygen_fraction
    hazard_fraction = initial_hazard_fraction

func step(seconds: float) -> void:
    if seconds <= 0.0:
        return
    simulated_seconds += seconds
    var exhausted: float = clampf((baseline_leak_rate + gas_injection_per_second) * seconds, 0.0, 1.0)
    oxygen_fraction = maxf(0.0, oxygen_fraction * (1.0 - exhausted))
    hazard_fraction = clampf(hazard_fraction + (1.0 - hazard_fraction) * exhausted, 0.0, 1.0)
    if station != null and bool(station.device_online.get(ventilation_device_id, false)):
        var exchange: float = clampf(fan_exchange_per_second * seconds, 0.0, 1.0)
        oxygen_fraction = lerpf(oxygen_fraction, initial_oxygen_fraction, exchange)
        hazard_fraction = lerpf(hazard_fraction, 0.0, exchange)
    atmosphere_changed.emit()

func is_safe() -> bool:
    return oxygen_fraction >= 0.18 and hazard_fraction <= 0.05

func snapshot() -> Dictionary:
    return {"oxygen": oxygen_fraction, "hazard": hazard_fraction, "injection": gas_injection_per_second, "seconds": simulated_seconds}

func restore(data: Dictionary) -> void:
    oxygen_fraction = clampf(float(data.get("oxygen", initial_oxygen_fraction)), 0.0, 1.0)
    hazard_fraction = clampf(float(data.get("hazard", initial_hazard_fraction)), 0.0, 1.0)
    gas_injection_per_second = maxf(float(data.get("injection", 0.0)), 0.0)
    simulated_seconds = maxf(float(data.get("seconds", 0.0)), 0.0)
    atmosphere_changed.emit()
