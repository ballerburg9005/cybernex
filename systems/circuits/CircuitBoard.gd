@tool
extends Resource
class_name CircuitBoard

@export_range(2, 40, 1) var width: int = 6
@export_range(2, 40, 1) var height: int = 6
@export var placements: Array[CircuitPlacement] = []
@export var required_load_part_id: String = "door_motor"
@export var min_load_volts: float = 4.0
@export var max_load_volts: float = 6.0
@export var minimum_hold_seconds: float = 0.5

func can_place(candidate: CircuitPlacement, skip_index: int = -1) -> bool:
    if candidate == null or candidate.part == null:
        return false
    var own: Rect2i = Rect2i(candidate.cell, candidate.footprint())
    if own.position.x < 0 or own.position.y < 0 or own.end.x > width or own.end.y > height:
        return false
    for i in range(placements.size()):
        if i == skip_index:
            continue
        var other: CircuitPlacement = placements[i]
        if other != null and other.part != null:
            if own.intersects(Rect2i(other.cell, other.footprint())):
                return false
    return true

func placement_at(cell: Vector2i) -> int:
    for i in range(placements.size()):
        var placement: CircuitPlacement = placements[i]
        if placement != null and placement.part != null:
            if Rect2i(placement.cell, placement.footprint()).has_point(cell):
                return i
    return -1
