@tool
extends Control
class_name CircuitBoardView

## One lightweight Control renders a whole board; no per-cell Area2Ds,
## duplicate sprites, per-cell _ready() loops or polling timers.
signal cell_clicked(cell: Vector2i)
signal board_changed

@export var board: CircuitBoard:
    set(next):
        board = next
        if is_inside_tree():
            update_minimum_size()
            queue_redraw()
@export_range(24, 128, 4) var cell_size: int = 68
var allow_dragging: bool = true
var inspected_voltages: Array = []
var hottest_part: int = -1

func _get_minimum_size() -> Vector2:
    if board == null:
        return Vector2(400, 300)
    return Vector2(board.width * cell_size, board.height * cell_size)

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        queue_redraw()

func _draw() -> void:
    if board == null:
        return
    var board_size: Vector2 = _get_minimum_size()
    draw_rect(Rect2(Vector2.ZERO, board_size), Color("#111824"), true)
    for y in range(board.height):
        for x in range(board.width):
            var rect := Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
            draw_rect(rect, Color("#2e3b4c"), false, 1.0)
    var font: Font = get_theme_default_font()
    for i in range(board.placements.size()):
        var placement: CircuitPlacement = board.placements[i]
        if placement == null or placement.part == null:
            continue
        var part: CircuitPart = placement.part
        var top_left: Vector2 = Vector2(placement.cell) * cell_size
        var size: Vector2 = Vector2(placement.footprint()) * cell_size
        var color: Color = Color("#406a92")
        match part.model:
            "wire": color = Color("#6e8459")
            "ground": color = Color("#665b86")
            "source": color = Color("#997449")
            "resistor": color = Color("#8c694b")
            "load": color = Color("#487c8d")
            "npn", "pnp", "nmos", "pmos": color = Color("#7772a3")
            "diode": color = Color("#779884")
        if placement.failed_open:
            color = Color("#913e45")
        draw_rect(Rect2(top_left + Vector2.ONE * 3.0, size - Vector2.ONE * 6.0), color, true)
        if i == hottest_part:
            draw_rect(Rect2(top_left + Vector2.ONE * 2.0, size - Vector2.ONE * 4.0), Color.ORANGE_RED, false, 3.0)
        var text: String = part.label
        draw_string(font, top_left + Vector2(7, minf(24.0, size.y * 0.5)), text, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - 12), 11, Color.WHITE)
        for pin in part.pins:
            if pin == null:
                continue
            var rotated: Dictionary = placement.rotated_pin(pin)
            var center: Vector2 = Vector2(rotated["cell"]) * cell_size + Vector2.ONE * cell_size * 0.5
            var delta: Vector2 = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN][rotated["side"]]
            draw_line(center + delta * cell_size * 0.30, center + delta * cell_size * 0.52, Color("#ffe5aa"), 4.0)
            draw_circle(center + delta * cell_size * 0.33, 3.0, Color.WHITE)

func _cell_from_position(local: Vector2) -> Vector2i:
    return Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))

func _inside(cell: Vector2i) -> bool:
    return board != null and cell.x >= 0 and cell.y >= 0 and cell.x < board.width and cell.y < board.height

func _gui_input(event: InputEvent) -> void:
    if Engine.is_editor_hint():
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var cell: Vector2i = _cell_from_position(event.position)
        if _inside(cell) and (allow_dragging or board.placement_at(cell) >= 0):
            cell_clicked.emit(cell)
            accept_event()

func _get_drag_data(at_position: Vector2) -> Variant:
    if Engine.is_editor_hint() or board == null or not allow_dragging:
        return null
    var cell: Vector2i = _cell_from_position(at_position)
    if not _inside(cell):
        return null
    var index: int = board.placement_at(cell)
    if index < 0 or board.placements[index].fixed_to_board:
        return null
    var preview := Label.new()
    preview.text = board.placements[index].part.label
    set_drag_preview(preview)
    return {"kind": "circuit_part", "source": self, "index": index}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
    if typeof(data) != TYPE_DICTIONARY or data.get("kind", "") != "circuit_part":
        return false
    if data.get("source") != self or board == null or not allow_dragging:
        return false
    var index: int = int(data["index"])
    if index < 0 or index >= board.placements.size():
        return false
    var moved: CircuitPlacement = board.placements[index].duplicate(true)
    moved.cell = _cell_from_position(at_position)
    return board.can_place(moved, index)

func _drop_data(at_position: Vector2, data: Variant) -> void:
    if not _can_drop_data(at_position, data):
        return
    var index: int = int(data["index"])
    board.placements[index].cell = _cell_from_position(at_position)
    queue_redraw()
    board_changed.emit()
