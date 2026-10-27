@tool
extends Resource
class_name RepairProcedure

## A repair is mechanical/logistical, not a scripted magic unlock.
## The target subsystem remains electrically and logically constrained.
@export var procedure_id: String = ""
@export var label: String = "Repair"
@export_multiline var service_note: String = ""
@export var target_device_id: String = ""
@export var target_module_id: String = ""
@export var needs_materials: Array[MaterialRequirement] = []
@export var needs_tools: PackedStringArray = PackedStringArray()
@export var requires_power_isolated: bool = true
@export var granted_protocol: String = ""
