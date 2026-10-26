@tool
extends Control
class_name CircuitBoardView

## Renderer and native drag target for Inspector-authored parts; all gameplay
## changes are validated by CircuitBoard before changing the topology.
signal cell_clicked(cell: Vector2i)
signal board_changed
signal rotation_requested(index: int)
signal incoming_part(item: InvItem, cell: Vector2i)
signal tool_applied(item: InvItem, cell: Vector2i)

@export var board: CircuitBoard:
    set(next):
        board = next
        pan_needs_center = true
        if is_inside_tree():
            call_deferred("_center_on_authored_board")
            queue_redraw()
@export_range(24, 128, 4) var cell_size: int = 64
var allow_dragging: bool = true
var workbench: CircuitWorkbench
var hottest_part: int = -1
@export_range(1, 40, 1) var pan_limit_cells: int = 20
var pan_offset: Vector2 = Vector2.ZERO
var pan_needs_center: bool = true
var middle_panning: bool = false

func _ready() -> void:
    resized.connect(func() -> void:
        if pan_needs_center:
            call_deferred("_center_on_authored_board")
        else:
            pan_offset = clamp_pan(pan_offset)
        queue_redraw()
    )
    call_deferred("_center_on_authored_board")

func _center_on_authored_board() -> void:
    if board == null or not is_inside_tree() or size.x < 1 or size.y < 1:
        return
    if pan_needs_center:
        pan_offset = size * 0.5 - Vector2(board.width, board.height) * cell_size * 0.5
        pan_needs_center = false
    pan_offset = clamp_pan(pan_offset)
    queue_redraw()

func clamp_pan(desired: Vector2) -> Vector2:
    if board == null:
        return desired
    # The visible viewport centre stays at most twenty blank cells outside
    # the actual board on each side.  No additional cells are authored.
    var focus: Vector2 = size * 0.5
    var padding: float = float(pan_limit_cells * cell_size)
    var board_pixels: Vector2 = Vector2(board.width, board.height) * cell_size
    return focus - Vector2(
        clampf(focus.x - desired.x, -padding, board_pixels.x + padding),
        clampf(focus.y - desired.y, -padding, board_pixels.y + padding)
    )

func pan_by(delta_pixels: Vector2) -> void:
    pan_needs_center = false
    pan_offset = clamp_pan(pan_offset + delta_pixels)
    queue_redraw()

const FRAME := Color("#1a2731")
const GRID := Color("#3a4a53")
const INK := Color("#d3e2df")
const SAFE_EDGE := Color("#8094a9")
const FAULT := Color("#aa4544")
const SIDES := [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]
const RESISTOR_BANDS: Texture2D = preload("res://UI/resistor_color_atlas.tres")

func _get_minimum_size() -> Vector2:
    # The authored board does NOT size the viewport: the finite footprint
    # floats in an infinite-looking canvas that fills the panel.
    return Vector2.ZERO

func _draw() -> void:
    if board == null:
        return
    draw_rect(Rect2(Vector2.ZERO, size), FRAME, true)
    # Draw only visible virtual cells: the texture appears endless while
    # off-board positions have no simulation data or possible placement.
    var first_x: int = floori(-pan_offset.x / cell_size) - 1
    var first_y: int = floori(-pan_offset.y / cell_size) - 1
    var last_x: int = ceili((size.x - pan_offset.x) / cell_size) + 1
    var last_y: int = ceili((size.y - pan_offset.y) / cell_size) + 1
    for y in range(first_y, last_y):
        for x in range(first_x, last_x):
            var rect := Rect2(pan_offset + Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
            var authored: bool = x >= 0 and y >= 0 and x < board.width and y < board.height
            draw_rect(rect.grow(-1.0), Color("#29423b") if authored else Color("#202b34"), true)
            draw_rect(rect.grow(-1.0), Color("#567b68") if authored else GRID, false, 1.0)
    # Render the electronic sprites, leads and notches in board coordinates.
    draw_set_transform(pan_offset)
    var font: Font = get_theme_default_font()
    for i in range(board.placements.size()):
        var placement: CircuitPlacement = board.placements[i]
        if placement == null or placement.part == null:
            continue
        var part: CircuitPart = placement.part
        var rect := Rect2(Vector2(placement.cell) * cell_size, Vector2(placement.footprint()) * cell_size)
        # Original pixel artwork is used rather than opaque colored blocks.
        # Keep non-square sprites proportional even on one-cell footprints.
        if part.sprite != null:
            var center: Vector2 = rect.get_center()
            var image_size: Vector2 = part.sprite.get_size()
            var rotated_size: Vector2 = image_size if placement.rotation % 2 == 0 else Vector2(image_size.y, image_size.x)
            var factor: float = minf((rect.size.x - 12.0) / rotated_size.x,
                                    (rect.size.y - 12.0) / rotated_size.y)
            var draw_size: Vector2 = image_size * maxf(factor, 0.1)
            draw_set_transform(pan_offset + center, placement.rotation * PI * 0.5)
            var drawing := Rect2(-draw_size * 0.5, draw_size)
            draw_texture_rect(part.sprite, drawing, false)
            if part.model == "resistor":
                _draw_color_bands(drawing, part.value)
            draw_set_transform(pan_offset)
        else:
            draw_rect(rect.grow(-9.0), Color("#57676d"), true)
        if placement.failed_open:
            draw_line(rect.position + Vector2(7, 7), rect.end - Vector2(7, 7), FAULT, 3)
            draw_line(Vector2(rect.end.x - 7, rect.position.y + 7),
                      Vector2(rect.position.x + 7, rect.end.y - 7), FAULT, 3)
        var text: String = _marking(part)
        if text != "":
            var pos := rect.position + Vector2(5, minf(rect.size.y - 6, 22))
            draw_rect(Rect2(pos - Vector2(2, 17), Vector2(minf(rect.size.x - 8, text.length() * 11 + 8), 23)),
                Color(0.04, 0.07, 0.09, 0.88), true)
            draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT,
                int(rect.size.x - 12), 17, 3, Color.BLACK)
            draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT,
                int(rect.size.x - 12), 17, INK)
        # Black corner notch denotes hard-fastened and immovable equipment.
        if placement.fixed_to_board or not part.can_remove:
            var pts := PackedVector2Array([rect.position + Vector2(1, 1),
                rect.position + Vector2(18, 1), rect.position + Vector2(1, 18)])
            draw_colored_polygon(pts, Color.BLACK)
        else:
            # Static desaturated green is preferred to distracting flashing.
            draw_rect(rect.grow(-3.0), SAFE_EDGE, false, 2.0)
        if i == hottest_part:
            draw_rect(rect.grow(-2.0), Color("#aa6840"), false, 2.0)
        for pin in part.pins:
            if pin == null:
                continue
            var rotated: Dictionary = placement.rotated_pin(pin)
            var center: Vector2 = (Vector2(rotated["cell"]) + Vector2.ONE * 0.5) * cell_size
            var outward: Vector2 = SIDES[int(rotated["side"])]
            draw_line(center + outward * cell_size * 0.30,
                      center + outward * cell_size * 0.52, Color("#e0d3a8"), 3.0)
    draw_set_transform(Vector2.ZERO)

func _marking(part: CircuitPart) -> String:
    match part.model:
        "resistor": return "" # Read resistance from the original color bands.
        "ground": return "GND"
        "load": return "MOTOR"
        "source": return "IN"
        "nmos", "pmos": return part.model.to_upper()
        "npn", "pnp": return part.model.to_upper()
        "diode": return "D"
    return ""

func _band_color(digit: int) -> Color:
    var bands: Array[Color] = [
        Color("#151515"), Color("#683b22"), Color("#cc292b"), Color("#db8129"),
        Color("#e5ca34"), Color("#348d45"), Color("#3159c4"), Color("#864696"),
        Color("#818181"), Color("#eeeeee"), Color("#b59a40")
    ]
    return bands[clampi(digit, 0, 10)]

func _draw_color_bands(body: Rect2, resistance: float) -> void:
    # Four bands: two significant digits, decimal magnitude, 5% gold.
    # No numeric ohm readout unless the player later obtains a meter.
    if resistance <= 0.0:
        return
    var decade: int = floori(log(resistance) / log(10.0))
    var significant: int = clampi(roundi(resistance / pow(10.0, decade - 1)), 10, 99)
    var digits := [significant / 10, significant % 10, clampi(decade - 1, 0, 9), 10]
    # The mask shapes are the original hand-drawn 4-band overlays from the
    # 128x16 legacy resistor atlas, tinted with standard EIA band colours.
    for i in range(4):
        draw_texture_rect_region(RESISTOR_BANDS, body,
            Rect2(i * 32, 0, 32, 16), _band_color(int(digits[i])))

func _cell_from_position(local: Vector2) -> Vector2i:
    return Vector2i(floori((local.x - pan_offset.x) / cell_size),
        floori((local.y - pan_offset.y) / cell_size))

func _inside(cell: Vector2i) -> bool:
    return board != null and cell.x >= 0 and cell.y >= 0 and cell.x < board.width and cell.y < board.height

func _gui_input(event: InputEvent) -> void:
    if Engine.is_editor_hint() or board == null:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
        middle_panning = event.pressed
        accept_event()
        return
    if event is InputEventMouseMotion and middle_panning:
        pan_by(event.relative)
        accept_event()
        return
    if event is InputEventMouseButton and event.pressed:
        var cell: Vector2i = _cell_from_position(event.position)
        if not _inside(cell):
            return
        if event.button_index == MOUSE_BUTTON_RIGHT:
            var index: int = board.placement_at(cell)
            if index >= 0 and allow_dragging:
                rotation_requested.emit(index)
                accept_event()
        elif event.button_index == MOUSE_BUTTON_LEFT:
            cell_clicked.emit(cell)
            accept_event()

func _get_drag_data(at_position: Vector2) -> Variant:
    if Engine.is_editor_hint() or board == null or not allow_dragging:
        return null
    var index: int = board.placement_at(_cell_from_position(at_position))
    if index < 0:
        return null
    var placement: CircuitPlacement = board.placements[index]
    if placement.fixed_to_board or not placement.part.can_remove:
        return null
    var preview := TextureRect.new()
    preview.texture = placement.part.sprite
    preview.custom_minimum_size = Vector2(64, 52)
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    set_drag_preview(preview)
    return {"kind": "circuit_part", "source": self, "index": index, "part": placement.part}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
    if typeof(data) != TYPE_DICTIONARY or board == null or not allow_dragging:
        return false
    var kind: String = str(data.get("kind", ""))
    var cell: Vector2i = _cell_from_position(at_position)
    if kind == "inventory_item":
        var item: InvItem = data.get("item")
        if item == null or not _inside(cell):
            return false
        if Inv.matches(item, preload("res://items/side_cutters.tres")):
            var target_index: int = board.placement_at(cell)
            return target_index >= 0 and board.placements[target_index].failed_open and workbench != null and workbench.can_extract_to(target_index, workbench.field_inventory)
        if item.circuit_part == null:
            return false
        var incoming := CircuitPlacement.new()
        incoming.part = item.circuit_part
        incoming.cell = cell
        return board.can_place(incoming)
    if kind != "circuit_part" or data.get("source") != self:
        return false
    var index: int = int(data.get("index", -1))
    if index < 0 or index >= board.placements.size():
        return false
    var moved: CircuitPlacement = board.placements[index].duplicate(true)
    moved.cell = cell
    return board.can_place(moved, index)

func _drop_data(at_position: Vector2, data: Variant) -> void:
    if not _can_drop_data(at_position, data):
        return
    var cell: Vector2i = _cell_from_position(at_position)
    if data.get("kind") == "inventory_item":
        if Inv.matches(data["item"], preload("res://items/side_cutters.tres")):
            tool_applied.emit(data["item"], cell)
        else:
            incoming_part.emit(data["item"], cell)
        return
    var index: int = int(data["index"])
    board.placements[index].cell = cell
    queue_redraw()
    board_changed.emit()
