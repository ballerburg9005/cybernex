@tool
extends Resource
class_name CircuitPin

## Pin geometry is defined in local UNROTATED footprint cells.
## Side order is clockwise: left, top, right, bottom.
@export_enum("left", "top", "right", "bottom") var side: int = 0
@export_range(0, 15, 1) var offset: int = 0
@export var name: String = "A"
## Used only by wire parts. Ports in the same group share a conductive hub.
@export_range(0, 7, 1) var wire_group: int = 0
