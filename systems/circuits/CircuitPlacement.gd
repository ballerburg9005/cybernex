@tool
extends Resource
class_name CircuitPlacement

@export var part: CircuitPart
@export var cell: Vector2i
@export_range(0, 3, 1) var rotation: int = 0
@export var fixed_to_board: bool = false
@export var failed_open: bool = false

func footprint() -> Vector2i:
    if part == null:
        return Vector2i.ONE
    var size: Vector2i = part.footprint
    if rotation % 2 == 1:
        return Vector2i(size.y, size.x)
    return size

func rotated_pin(pin: CircuitPin) -> Dictionary:
    var w: int = part.footprint.x
    var h: int = part.footprint.y
    var point := Vector2i.ZERO
    match pin.side:
        0: point = Vector2i(0, pin.offset)
        1: point = Vector2i(pin.offset, 0)
        2: point = Vector2i(w - 1, pin.offset)
        3: point = Vector2i(pin.offset, h - 1)
    for step in range(rotation % 4):
        point = Vector2i(h - 1 - point.y, point.x)
        var previous_w: int = w
        w = h
        h = previous_w
    return {"cell": cell + point, "side": (pin.side + rotation) % 4}
