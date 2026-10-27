@tool
extends Resource
class_name PowerBusSpec

## Different domains cannot be connected directly. Converter devices bridge them.
@export var bus_id: String = "DC_A"
@export_enum("low voltage DC", "industrial AC", "pulsed HV") var domain: String = "low voltage DC"
@export_range(1.0, 100000.0, 1.0) var nominal_volts: float = 48.0
@export_range(0.0, 100000000.0, 1.0) var capacity_watts: float = 1000.0
@export var powered: bool = true
@export_range(0.0, 1000.0, 0.1) var duty_period_seconds: float = 0.0
@export_range(0.0, 1.0, 0.01) var duty_fraction: float = 1.0
