@tool
extends Resource
class_name CircuitPart

## Author in the Godot Inspector; parts are reusable, immutable templates.
@export var part_id: String = ""
@export var label: String = "Part"
@export_enum("wire", "resistor", "source", "ground", "load", "diode", "npn", "pnp", "nmos", "pmos") var model: String = "wire"
@export var footprint: Vector2i = Vector2i.ONE
@export var sprite: Texture2D
@export var pins: Array[CircuitPin] = []
## Resistor/load/wire ohms; source volts; MOSFET on-resistance.
@export_range(0.001, 100000000.0, 0.001, "or_greater") var value: float = 1.0
## Source series ohms; diode forward drop; transistor threshold (V).
@export_range(0.001, 100000.0, 0.001, "or_greater") var secondary_value: float = 0.2
## BJT gain (beta), or semiconductor resistance multiplier in future models.
@export_range(1.0, 1000.0, 1.0) var gain: float = 60.0
@export_range(0.001, 1000000.0, 0.001, "or_greater") var rated_watts: float = 0.25
@export_range(0.001, 10000.0, 0.001, "or_greater") var thermal_capacity: float = 2.0
@export_range(0.001, 1000.0, 0.001, "or_greater") var cooling_watts_per_kelvin: float = 0.04
@export_range(20.0, 2000.0, 1.0) var failure_temperature_c: float = 160.0
@export var can_remove: bool = true
@export var can_rotate: bool = true
