extends Control
class_name CircuitWorkbench

## Standalone vertical slice. Godot Inspector edits the .tres templates and
## board placements; runtime uses the same resources without modifying originals.
signal puzzle_solved
signal journal_event(message: String)
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
var meter_unlocked: bool = false
var last_joint_method: String = "solder"

func _ready() -> void:
    if authored_board == null:
        status.text = "Assign a CircuitBoard resource in the Inspector."
        return
    board = authored_board.duplicate(true)
    board_view.board = board
    board_view.workbench = self
    for part in catalog:
        if part != null:
            palette.add_item(part.label)
    _refresh_palette_labels()
    board_view.cell_clicked.connect(_on_board_click)
    board_view.board_changed.connect(_topology_changed)
    board_view.rotation_requested.connect(_rotate_at_index)
    board_view.incoming_part.connect(_install_inventory_part)
    board_view.tool_applied.connect(_apply_tool_to_board)
    timer.timeout.connect(_on_simulation_tick)
    %RotateButton.pressed.connect(_rotate_selected)
    %RemoveButton.pressed.connect(_remove_selected)
    run_button.pressed.connect(_toggle_running)
    status.text = ""
    board_view.queue_redraw()

func _on_board_click(cell: Vector2i) -> void:
    if board == null:
        return
    var index: int = board.placement_at(cell)
    if index >= 0:
        selected_index = index
        _refresh_probe()
        status.text = ""
        return
    if not timer.is_stopped():
        return
    if field_inventory != null:
        return # Player must drag a physical spare from the inventory.
    var new_part := CircuitPlacement.new()
    new_part.part = catalog[palette.selected]
    new_part.cell = cell
    if board.can_place(new_part):
        if not _spend_component(new_part.part):
            return
        new_part.joint_resistance_ohms = 0.32 if last_joint_method == "tape" else 0.0
        board.placements.append(new_part)
        selected_index = board.placements.size() - 1
        _topology_changed()
    else:
        _announce("The component does not fit the available footprint.")

func _rotate_selected() -> void:
    _rotate_at_index(selected_index)

func _rotate_at_index(index: int) -> void:
    if not timer.is_stopped():
        return
    if index < 0 or index >= board.placements.size():
        return
    selected_index = index
    var old: CircuitPlacement = board.placements[index]
    if old.fixed_to_board or not old.part.can_rotate:
        _announce("The component is riveted to the chassis.")
        return
    var rotated: CircuitPlacement = old.duplicate(true)
    rotated.rotation = (rotated.rotation + 1) % 4
    if board.can_place(rotated, index):
        board.placements[index] = rotated
        _topology_changed()
    else:
        _announce("No clearance to rotate this footprint.")

func _remove_selected() -> void:
    if not timer.is_stopped():
        return
    if selected_index < 0 or selected_index >= board.placements.size():
        return
    if board.placements[selected_index].fixed_to_board or not board.placements[selected_index].part.can_remove:
        _announce("The component cannot be extracted.")
        return
    if field_inventory != null and not _can_store_extracted(selected_index, field_inventory):
        _announce("There is no room to keep the recovered component.")
        return
    if not _extraction_cost(selected_index):
        return
    var removed: CircuitPlacement = board.placements[selected_index]
    if field_inventory != null:
        if removed.failed_open:
            field_inventory.add_item(preload("res://items/junk.tres"), 1)
        else:
            var reclaimed: InvItem = _tool_item(removed.held_item_id) if not removed.held_item_id.is_empty() else _part_item(removed.part)
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
    run_button.text = "POWER"
    simulation = CircuitSimulation.new()
    last_measurement = {}
    if is_node_ready():
        probe_report.text = ""
    already_solved = false
    status.text = ""
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
        _announce("Electrical fault: " + "; ".join(state["errors"]))
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
        _announce("Overcurrent destroyed an exposed component.")
        return
    if meter_unlocked:
        status.text = "%.3f V  /  %.1f °C" % [voltage, highest]
    if state["solved"] and not already_solved:
        already_solved = true
        _announce("Actuator relay accepted the restored circuit.")
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
    last_joint_method = "solder"
    if field_inventory != null:
        var item: InvItem = _part_item(part)
        var solder: InvItem = preload("res://items/solder.tres")
        var tape: InvItem = preload("res://items/insulation_tape.tres")
        var joining: InvItem = solder
        if not field_inventory.has(solder) and part.model == "wire" and field_inventory.has(tape):
            joining = tape
            last_joint_method = "tape"
        if item == null or not field_inventory.has(item) or not field_inventory.has(joining):
            _announce("The joint needs a compatible spare and solder or suitable insulation tape.")
            return false
        if not field_inventory.remove_item(item, 1):
            return false
        if not field_inventory.remove_item(joining, 1):
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
                "failed": placement.failed_open,
                "joint": placement.joint_resistance_ohms,
                "held_item": placement.held_item_id
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
        var held_id: String = str(saved.get("held_item", ""))
        if not held_id.is_empty():
            var tool: InvItem = _tool_item(held_id)
            if tool == null or part_id != "contact_" + held_id:
                return false
            catalog_by_id[part_id] = _contact_part(tool)
        if not catalog_by_id.has(part_id):
            return false
        var placement := CircuitPlacement.new()
        placement.part = catalog_by_id[part_id]
        placement.cell = Vector2i(int(saved.get("x", -1)), int(saved.get("y", -1)))
        placement.rotation = posmod(int(saved.get("rotation", 0)), 4)
        placement.fixed_to_board = bool(saved.get("fixed", false))
        placement.held_item_id = held_id
        placement.failed_open = bool(saved.get("failed", false))
        placement.joint_resistance_ohms = float(saved.get("joint", 0.0))
        if not is_finite(placement.joint_resistance_ohms) or placement.joint_resistance_ohms < 0.0 or placement.joint_resistance_ohms > 10.0:
            return false
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
    if not meter_unlocked:
        probe_report.text = ""
        return
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

func _announce(message: String) -> void:
    if is_node_ready():
        status.text = message
    journal_event.emit(message)

func set_meter_unlocked(value: bool) -> void:
    meter_unlocked = value
    _refresh_probe()

func _install_inventory_part(item: InvItem, cell: Vector2i) -> void:
    if timer == null or not timer.is_stopped() or board == null:
        return
    if item == null or item.circuit_part == null or field_inventory == null:
        return
    var placement := CircuitPlacement.new()
    placement.part = item.circuit_part
    placement.cell = cell
    if not board.can_place(placement):
        _announce("The part cannot fit the empty pad.")
        return
    if not _spend_component(placement.part):
        _announce("Missing spare part or fresh solder for the joint.")
        return
    placement.joint_resistance_ohms = 0.32 if last_joint_method == "tape" else 0.0
    board.placements.append(placement)
    selected_index = board.placements.size() - 1
    _topology_changed()

func can_extract_to(index: int, pack: Inv) -> bool:
    if board == null or pack == null or not timer.is_stopped():
        return false
    if index < 0 or index >= board.placements.size():
        return false
    var placement: CircuitPlacement = board.placements[index]
    if placement.fixed_to_board or not placement.part.can_remove:
        return false
    if not placement.held_item_id.is_empty() and not placement.failed_open:
        return _can_store_extracted(index, pack)
    if placement.failed_open:
        return pack.has(preload("res://items/side_cutters.tres")) and _can_store_extracted(index, pack)
    if placement.joint_resistance_ohms > 0.0:
        return _can_store_extracted(index, pack) # Peel cold tape without solder.
    return pack.has(preload("res://items/solder.tres")) and _can_store_extracted(index, pack)

func extract_to_backpack(index: int, pack: Inv) -> bool:
    if pack != field_inventory or not can_extract_to(index, pack):
        _announce("Removing a soldered part requires solder; a burnt part must be cut with pliers.")
        return false
    selected_index = index
    var previous: int = board.placements.size()
    _remove_selected()
    return board.placements.size() < previous

func _can_store_extracted(index: int, stock: Inv) -> bool:
    var placement: CircuitPlacement = board.placements[index]
    var recovered: InvItem = preload("res://items/junk.tres") if placement.failed_open else (
        _tool_item(placement.held_item_id) if not placement.held_item_id.is_empty() else _part_item(placement.part))
    if recovered == null:
        return true
    var preview: Inv = stock.duplicate(true)
    if not placement.failed_open and placement.held_item_id.is_empty() and placement.joint_resistance_ohms <= 0.0:
        preview.remove_item(preload("res://items/solder.tres"), 1)
    return preview.can_add(recovered, 1)

func _extraction_cost(index: int) -> bool:
    if field_inventory == null:
        return true # Standalone circuit test bench does not carry real stock.
    var placement: CircuitPlacement = board.placements[index]
    if not placement.held_item_id.is_empty() and not placement.failed_open:
        return true # Simply pick up the loose conducting tool, without solder.
    if placement.failed_open:
        if not field_inventory.has(preload("res://items/side_cutters.tres")):
            _announce("Side cutters required to snap out the burnt lead.")
            return false
        return true
    if placement.joint_resistance_ohms > 0.0:
        return true
    var solder: InvItem = preload("res://items/solder.tres")
    if not field_inventory.remove_item(solder, 1):
        _announce("Fresh solder required to desolder an intact component.")
        return false
    return true

## The tool itself is the low-ohm element: it stays on the board, is removed
## from the backpack, heats under load and can be recovered without solder.
## Tools with no authored contact resistance (including guns) are incompatible.
func _tool_item(item_id: String) -> InvItem:
    for candidate in item_catalog:
        if candidate != null and candidate.item_id == item_id and candidate.contact_resistance_ohms > 0.0:
            return candidate
    return null

func _contact_part(item: InvItem) -> CircuitPart:
    var part := CircuitPart.new()
    part.part_id = "contact_" + item.item_id
    part.label = item.short_name if not item.short_name.is_empty() else item.name
    part.model = "wire"
    part.footprint = Vector2i.ONE
    part.sprite = item.texture
    part.value = item.contact_resistance_ohms
    part.rated_watts = item.contact_rated_watts
    part.thermal_capacity = 0.5
    part.cooling_watts_per_kelvin = 0.04
    part.failure_temperature_c = 120.0
    var left := CircuitPin.new()
    left.name = "L"
    left.side = 0
    var right := CircuitPin.new()
    right.name = "R"
    right.side = 2
    part.pins = [left, right]
    return part

func _has_facing_terminal(cell: Vector2i, face: int) -> bool:
    if board == null:
        return false
    var index: int = board.placement_at(cell)
    if index < 0:
        return false
    var placement: CircuitPlacement = board.placements[index]
    if placement.failed_open:
        return false
    for pin in placement.part.pins:
        if pin == null:
            continue
        var exposed: Dictionary = placement.rotated_pin(pin)
        if exposed["cell"] == cell and int(exposed["side"]) == face:
            return true
    return false

func _contact_orientation(cell: Vector2i) -> int:
    if board == null or not board.can_place(_candidate_contact(cell)):
        return -1
    if _has_facing_terminal(cell + Vector2i.LEFT, 2) and _has_facing_terminal(cell + Vector2i.RIGHT, 0):
        return 0
    if _has_facing_terminal(cell + Vector2i.UP, 3) and _has_facing_terminal(cell + Vector2i.DOWN, 1):
        return 1
    return -1

func _candidate_contact(cell: Vector2i) -> CircuitPlacement:
    var candidate := CircuitPlacement.new()
    candidate.cell = cell
    candidate.part = preload("res://systems/circuits/parts/wire_straight.tres")
    return candidate

func can_bridge_with_tool(item: InvItem, cell: Vector2i) -> bool:
    return item != null and not item.item_id.is_empty() and item.contact_resistance_ohms > 0.0 \
        and item.contact_rated_watts > 0.0 and field_inventory != null and field_inventory.has(item) \
        and timer != null and timer.is_stopped() and _contact_orientation(cell) >= 0

func _apply_tool_to_board(item: InvItem, cell: Vector2i) -> void:
    if board == null or field_inventory == null or not timer.is_stopped() or item == null:
        return
    var part_index: int = board.placement_at(cell)
    if part_index >= 0:
        if not Inv.matches(item, preload("res://items/side_cutters.tres")):
            return
        if not board.placements[part_index].failed_open or not field_inventory.has(item):
            return
        if extract_to_backpack(part_index, field_inventory):
            _announce("Burnt leads snapped. The cutters remain usable.")
        return
    if not can_bridge_with_tool(item, cell):
        return
    var rotation: int = _contact_orientation(cell)
    var placement := CircuitPlacement.new()
    placement.part = _contact_part(item)
    placement.cell = cell
    placement.rotation = rotation
    placement.held_item_id = item.item_id
    if not board.can_place(placement) or not field_inventory.remove_item(item, 1):
        return
    board.placements.append(placement)
    selected_index = board.placements.size() - 1
    _topology_changed()
    _announce("%s rests across the contacts." % item.name)
