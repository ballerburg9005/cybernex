@tool
extends Resource
class_name StationDeviceSpec

## World objects reference persistent logical devices; no hard-coded door flags.
@export var device_id: String = "door_a"
@export_enum("consumer", "converter", "security", "ventilation", "robotics", "door") var device_type: String = "consumer"
@export var supply_bus: String = "DC_A"
@export var output_bus: String = ""
@export_range(0.0, 1000000.0, 1.0) var demand_watts: float = 25.0
@export_range(0.0, 1000000.0, 1.0) var conversion_capacity_watts: float = 0.0
@export_range(0.01, 1.0, 0.01) var efficiency: float = 0.85
@export var required_devices: PackedStringArray = PackedStringArray()
@export var requires_protocol: String = ""
@export var intact: bool = true
@export var operator_enabled: bool = true
