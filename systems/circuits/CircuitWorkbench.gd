extends Control
class_name CircuitWorkbench

## Standalone vertical slice. Godot Inspector edits the .tres templates and
## board placements; runtime uses the same resources without modifying originals.
signal puzzle_solved
@export var authored_board: CircuitBoard
@export var catalog: Array[CircuitPart] = []

@onready var board_view: CircuitBoardView = %BoardView
@onready var palette: OptionButton = %Palette
@onready var status: Label = %Status
@onready var run_button: Button = %RunButton
@onready var timer: Timer = %SolveTimer

var board: CircuitBoard
## Optional shared resource from the station bay. Standalone mode remains unlimited.
var supplied_inventory: SalvageInventory
var require_salvage: bool = false
var simulation := CircuitSimulation.new()
var selected_index: int = -1
var already_solved: bool = false

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
        status.text = "Selected: %s. Drag to reposition, or rotate." % board.placements[index].part.label
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
    if selected_index < 0 or selected_index >= board.placements.size():
        return
    if board.placements[selected_index].fixed_to_board or not board.placements[selected_index].part.can_remove:
        status.text = "This board component cannot be removed."
        return
    var removed: CircuitPlacement = board.placements[selected_index]
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
    status.text = "Load: %.3f V | hottest: %.1f C | stable: %.2fs" % [voltage, highest, state["hold_seconds"]]
    if state["solved"] and not already_solved:
        already_solved = true
        status.text += " | ACCESS ACTUATOR READY"
        puzzle_solved.emit()

func set_inventory(stock: SalvageInventory) -> void:
    # Called by the owning gameplay scene after this Control enters the tree.
    supplied_inventory = stock
    require_salvage = stock != null
    _refresh_palette_labels()

func _refresh_palette_labels() -> void:
    if not is_node_ready():
        return
    var i: int = 0
    for part in catalog:
        if part == null:
            continue
        var text: String = part.label
        if require_salvage and supplied_inventory != null:
            text += "  [×%d]" % supplied_inventory.amount(part.part_id)
        if i < palette.item_count:
            palette.set_item_text(i, text)
        i += 1

func _spend_component(part: CircuitPart) -> bool:
    if not require_salvage or supplied_inventory == null:
        return true
    var requirement := MaterialRequirement.new()
    requirement.item_id = part.part_id
    requirement.quantity = 1
    if not supplied_inventory.consume([requirement]):
        status.text = "No %s available. Scavenge a spare or improvise." % part.label
        return false
    _refresh_palette_labels()
    return true
