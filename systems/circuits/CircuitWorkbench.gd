extends Control
class_name CircuitWorkbench

## Standalone vertical slice. Godot Inspector edits the .tres templates and
## board placements; runtime uses the same resources without modifying originals.
signal puzzle_solved
@export var authored_board: CircuitBoard
@export var catalog: Array[CircuitPart] = []
@export var item_catalog: Array[InvItem] = []

@onready var board_view: CircuitBoardView = %BoardView
@onready var palette: OptionButton = %Palette
@onready var status: Label = %Status
@onready var run_button: Button = %RunButton
@onready var timer: Timer = %SolveTimer
@onready var probe_report: Label = %ProbeReport

var board: CircuitBoard
## Optional shared resource from the station bay. Standalone mode remains unlimited.
var supplied_inventory: SalvageInventory
var field_inventory: Inv
var require_salvage: bool = false
var simulation := CircuitSimulation.new()
var selected_index: int = -1
var already_solved: bool = false
var last_measurement: Dictionary = {}

func _ready() -> void:
    if authored_board == null:
        status.text = "Assign a CircuitBoard resource in the Inspector."
        return
    board = authored_board.duplicate(true)
    board_view.board = board
    for part in catalog:
        if part != null:
            palette.add_item(part.label)
    _refresh_palette_labels()
    board_view.cell_clicked.connect(_on_board_click)
    board_view.board_changed.connect(_topology_changed)
    timer.timeout.connect(_on_simulation_tick)
    %RotateButton.pressed.connect(_rotate_selected)
    %RemoveButton.pressed.connect(_remove_selected)
    run_button.pressed.connect(_toggle_running)
    status.text = "Repair the circuit, then RUN. Click a part to select it."
    board_view.queue_redraw()

func _on_board_click(cell: Vector2i) -> void:
    if board == null:
        return
    var index: int = board.placement_at(cell)
    if index >= 0:
        selected_index = index
        _refresh_probe()
        status.text = "Selected: %s. Drag to reposition, or rotate." % board.placements[index].part.label
        return
    if not timer.is_stopped():
        return
    if catalog.is_empty() or palette.selected < 0:
        return
    var new_part := CircuitPlacement.new()
    new_part.part = catalog[palette.selected]
    new_part.cell = cell
    if board.can_place(new_part):
        if not _spend_component(new_part.part):
            return
        board.placements.append(new_part)
        selected_index = board.placements.size() - 1
        _topology_changed()
    else:
        status.text = "No room: footprint overlaps an occupied cell."

func _rotate_selected() -> void:
    if not timer.is_stopped():
        return
    if selected_index < 0 or selected_index >= board.placements.size():
        return
    var old: CircuitPlacement = board.placements[selected_index]
    if old.fixed_to_board or not old.part.can_rotate:
        status.text = "This board component is fixed."
        return
    var rotated: CircuitPlacement = old.duplicate(true)
    rotated.rotation = (rotated.rotation + 1) % 4
    if board.can_place(rotated, selected_index):
        board.placements[selected_index] = rotated
        _topology_changed()

func _remove_selected() -> void:
    if not timer.is_stopped():
        return
    if selected_index < 0 or selected_index >= board.placements.size():
        return
    if board.placements[selected_index].fixed_to_board or not board.placements[selected_index].part.can_remove:
        status.text = "This board component cannot be removed."
        return
    var removed: CircuitPlacement = board.placements[selected_index]
    if field_inventory != null:
        if removed.failed_open:
            field_inventory.add_item(preload("res://items/junk.tres"), 1)
        else:
            var reclaimed: InvItem = _part_item(removed.part)
            if reclaimed != null and not field_inventory.add_item(reclaimed, 1):
                status.text = "Pack full. Cannot recover intact component."
                return
    if require_salvage and supplied_inventory != null:
        if removed.failed_open:
            supplied_inventory.add("electronic_scrap", 1, "Burnt electronic scrap")
        else:
            supplied_inventory.add(removed.part.part_id, 1, removed.part.label)
    board.placements.remove_at(selected_index)
    selected_index = -1
    _topology_changed()

func _topology_changed() -> void:
    # Editing while energized is prohibited: realistic live-circuit edits come later.
    timer.stop()
    run_button.text = "RUN"
    simulation = CircuitSimulation.new()
    last_measurement = {}
    if is_node_ready():
        probe_report.text = "No measurement: board changed."
    already_solved = false
    status.text = "Layout changed. RUN to measure voltage and temperature."
    board_view.queue_redraw()
    board_view.allow_dragging = true
    _refresh_palette_labels()

func _toggle_running() -> void:
    if timer.is_stopped():
        timer.start()
        run_button.text = "PAUSE"
        board_view.allow_dragging = false
    else:
        timer.stop()
        run_button.text = "RUN"
        board_view.allow_dragging = true

func _on_simulation_tick() -> void:
    if board == null:
        return
    var state: Dictionary = simulation.step(board, timer.wait_time)
    last_measurement = state
    if not state["errors"].is_empty():
        status.text = "Solver: " + "; ".join(state["errors"])
        timer.stop()
        run_button.text = "RUN"
        board_view.allow_dragging = true
        return
    var voltage: float = float(state["loads"].get(board.required_load_part_id, 0.0))
    var highest: float = 0.0
    var index: int = -1
    for key in state["temperatures_c"]:
        var temperature: float = float(state["temperatures_c"][key])
        if temperature > highest:
            highest = temperature
            index = int(key)
    board_view.hottest_part = index if highest > 50.0 else -1
    board_view.queue_redraw()
    _refresh_probe()
    if state.has("newly_failed") and not state["newly_failed"].is_empty():
        status.text = "Overcurrent/thermal failure destroyed part(s): %s" % str(state["newly_failed"])
        return
    status.text = "Load: %.3f V | hottest: %.1f C | stable: %.2fs" % [voltage, highest, state["hold_seconds"]]
    if state["solved"] and not already_solved:
        already_solved = true
        status.text += " | ACCESS ACTUATOR READY"
        puzzle_solved.emit()

func set_field_inventory(stock: Inv) -> void:
    field_inventory = stock
    require_salvage = stock != null or supplied_inventory != null
    _refresh_palette_labels()

func _part_item(part: CircuitPart) -> InvItem:
    for stock in item_catalog:
        if stock != null and stock.circuit_part != null and stock.circuit_part.part_id == part.part_id:
            return stock
    return null

func set_inventory(stock: SalvageInventory) -> void:
    # Called by the owning gameplay scene after this Control enters the tree.
    supplied_inventory = stock
    require_salvage = stock != null or field_inventory != null
    _refresh_palette_labels()

func _refresh_palette_labels() -> void:
    if not is_node_ready():
        return
    var i: int = 0
    for part in catalog:
        if part == null:
            continue
        var text: String = part.label
        if field_inventory != null:
            var inventory_item: InvItem = _part_item(part)
            text += "  [×%d]" % (field_inventory.count(inventory_item) if inventory_item != null else 0)
        elif require_salvage and supplied_inventory != null:
            text += "  [×%d]" % supplied_inventory.amount(part.part_id)
        if i < palette.item_count:
            palette.set_item_text(i, text)
        i += 1

func _spend_component(part: CircuitPart) -> bool:
    if field_inventory != null:
        var item: InvItem = _part_item(part)
        var solder: InvItem = preload("res://items/solder.tres")
        if item == null or not field_inventory.has(item) or not field_inventory.has(solder):
            status.text = "Need a compatible spare component and a solder segment."
            return false
        if not field_inventory.remove_item(item, 1):
            return false
        if not field_inventory.remove_item(solder, 1):
            field_inventory.add_item(item, 1)
            return false
        _refresh_palette_labels()
        return true
    if not require_salvage or supplied_inventory == null:
        return true
    var requirement := MaterialRequirement.new()
    requirement.item_id = part.part_id
    requirement.quantity = 1
    var solder := MaterialRequirement.new()
    solder.item_id = "solder"
    solder.quantity = 1
    if not supplied_inventory.consume([requirement, solder]):
        status.text = "Requires %s and one unit of solder. Check salvage." % part.label
        return false
    _refresh_palette_labels()
    return true

func snapshot() -> Dictionary:
    var parts: Array[Dictionary] = []
    if board != null:
        for placement in board.placements:
            if placement == null or placement.part == null:
                continue
            parts.append({
                "part_id": placement.part.part_id,
                "x": placement.cell.x, "y": placement.cell.y,
                "rotation": placement.rotation,
                "fixed": placement.fixed_to_board,
                "failed": placement.failed_open
            })
    return {"placements": parts}

func restore(data: Dictionary) -> bool:
    if authored_board == null or not data.has("placements"):
        return false
    var catalog_by_id: Dictionary = {}
    for part in catalog:
        if part != null:
            catalog_by_id[part.part_id] = part
    for placement in authored_board.placements:
        if placement != null and placement.part != null:
            catalog_by_id[placement.part.part_id] = placement.part
    var restored: CircuitBoard = authored_board.duplicate(true)
    restored.placements.clear()
    for saved in data["placements"]:
        if typeof(saved) != TYPE_DICTIONARY:
            return false
        var part_id: String = str(saved.get("part_id", ""))
        if not catalog_by_id.has(part_id):
            return false
        var placement := CircuitPlacement.new()
        placement.part = catalog_by_id[part_id]
        placement.cell = Vector2i(int(saved.get("x", -1)), int(saved.get("y", -1)))
        placement.rotation = posmod(int(saved.get("rotation", 0)), 4)
        placement.fixed_to_board = bool(saved.get("fixed", false))
        placement.failed_open = bool(saved.get("failed", false))
        if not restored.can_place(placement):
            return false
        restored.placements.append(placement)
    board = restored
    board_view.board = restored
    selected_index = -1
    _topology_changed()
    return true

func _refresh_probe() -> void:
    if not is_node_ready() or probe_report == null:
        return
    if selected_index < 0 or board == null or selected_index >= board.placements.size():
        probe_report.text = "Click a part to probe. Run circuit for live readings."
        return
    var placement: CircuitPlacement = board.placements[selected_index]
    var part: CircuitPart = placement.part
    var lines := PackedStringArray()
    lines.append("DMM // %s" % part.label)
    lines.append("ID %s | %s" % [part.part_id, "FAILED OPEN" if placement.failed_open else "present"])
    if last_measurement.has("voltages"):
        var voltages: Array = last_measurement["voltages"]
        var compiled: Dictionary = CircuitCompiler.compile(board)
        for element in compiled["elements"]:
            if int(element["part_index"]) != selected_index:
                continue
            if element.has("pins"):
                var pins: Dictionary = element["pins"]
                for pin_name in pins:
                    var node_idx: int = int(pins[pin_name])
                    if node_idx >= 0 and node_idx < voltages.size():
                        lines.append("%s = %.4f V" % [pin_name, float(voltages[node_idx])])
            elif element.has("a"):
                lines.append("wire %s: %.4f V → %.4f V" % [
                    element["id"], float(voltages[element["a"]]), float(voltages[element["b"]])])
            var amperes: float = float(last_measurement.get("currents", {}).get(element["id"], 0.0))
            lines.append("I = %.5f A" % amperes)
        var watts: float = float(last_measurement.get("watts", {}).get(selected_index, 0.0))
        var temperature: float = float(last_measurement.get("temperatures_c", {}).get(selected_index, 23.0))
        lines.append("P = %.4f W  |  T = %.1f C" % [watts, temperature])
    probe_report.text = "\n".join(lines)
