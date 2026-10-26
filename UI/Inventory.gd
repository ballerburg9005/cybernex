extends PanelContainer
class_name InventoryView

## One inventory is the source of truth. Change signals rebuild only visible
## controls, replacing 200ms polling and per-cell physics collisions.
signal feedback(message: String)
signal use_requested(item: InvItem)
signal save_requested
signal load_requested
signal world_drop_requested(origin: Inv, origin_index: int, item: InvItem, viewport_position: Vector2)
@export var inv: Inv
@export_enum("backpack", "hotbar") var mode: String = "backpack"
@export_range(1, 12, 1) var preferred_columns: int = 7
@export_range(1, 20, 1) var empty_slots_to_show: int = 10

@onready var grid_container: GridContainer = $Layout/Scroll/GridContainer
@onready var counter: Label = $Layout/Toolbar/Counter
@onready var filter_button: OptionButton = $Layout/Actions/Filter
@onready var sort_button: Button = $Layout/Actions/Sort
@onready var search_input: LineEdit = $Layout/SearchBar/Search
@onready var visible_count: Label = $Layout/SearchBar/VisibleCount
@onready var info: Label = $Layout/Feedback

var backpack: Inv
var cells_scene: PackedScene = preload("res://UI/InventoryItem.tscn")
var filtering: int = 0

func _ready() -> void:
    filter_button.add_item("ALL ITEMS")
    filter_button.add_item("TOOLS")
    filter_button.add_item("WEAPONS")
    filter_button.add_item("AUGMENTS")
    filter_button.add_item("MATERIALS / JUNK")
    filter_button.add_item("FOOD")
    filter_button.item_selected.connect(func(idx: int) -> void:
        filtering = idx
        refresh()
    )
    search_input.text_changed.connect(func(_new_text: String) -> void:
        refresh()
    )
    sort_button.pressed.connect(func() -> void:
        if inv != null and mode != "hotbar":
            inv.sort_by_category()
    )
    $Layout/Actions/Save.pressed.connect(func() -> void: save_requested.emit())
    $Layout/Actions/Load.pressed.connect(func() -> void: load_requested.emit())
    if inv == null:
        inv = Inv.new()
    configure(inv, null, mode)

func configure(model: Inv, owner_inventory: Inv = null, display_mode: String = "backpack") -> void:
    if inv != null and inv.changed.is_connected(refresh):
        inv.changed.disconnect(refresh)
    if backpack != null and backpack != inv and backpack.changed.is_connected(_backpack_updated):
        backpack.changed.disconnect(_backpack_updated)
    inv = model
    backpack = owner_inventory if owner_inventory != null else model
    mode = display_mode
    if inv == null:
        return
    inv.ensure_slots()
    if mode != "hotbar":
        inv.normalize()
    else:
        # Quickbar entries are references to backpack items, never duplicated stock.
        for i in range(inv.size()):
            if inv.items[i] == null:
                inv.items[i] = InvSlot.new()
    inv.changed.connect(refresh)
    if backpack != null and backpack != inv:
        backpack.changed.connect(_backpack_updated)
    if is_node_ready():
        refresh()

func _backpack_updated() -> void:
    # Expire linked quickslots when the last actual item is consumed.
    if mode == "hotbar" and backpack != null:
        var modified: bool = false
        for i in range(inv.size()):
            var stack: InvSlot = inv.slot_at(i)
            if stack != null and not backpack.has(stack.item):
                inv.items[i] = InvSlot.new()
                modified = true
        if modified:
            inv.emit_changed()
    refresh()

func _allowed(item: InvItem) -> bool:
    if mode != "hotbar" and is_node_ready() and not search_input.text.strip_edges().is_empty():
        var search: String = search_input.text.strip_edges().to_lower()
        var haystack: String = (item.name + " " + item.short_name + " " + item.description).to_lower()
        if not haystack.contains(search):
            return false
    if filtering == 0 or mode == "hotbar":
        return true
    match filtering:
        1: return item.type & InvItem.IS_TOOL != 0
        2: return item.type & InvItem.IS_WEAPON != 0
        3: return item.type & InvItem.IS_AUGMENTATION != 0
        4: return item.type & InvItem.IS_JUNK != 0 or item.type == 0
        5: return item.type & InvItem.IS_FOOD != 0
    return true

func refresh() -> void:
    if not is_node_ready() or inv == null:
        return
    var occupied: Array[int] = []
    var available: Array[int] = []
    var shown_quantity: int = 0
    for i in range(inv.size()):
        var slot: InvSlot = inv.slot_at(i)
        if slot != null:
            if _allowed(slot.item):
                occupied.append(i)
                shown_quantity += slot.count
        else:
            available.append(i)
    var indices: Array[int] = []
    if mode == "hotbar":
        for i in range(inv.size()):
            indices.append(i)
    else:
        indices.append_array(occupied)
        if filtering == 0:
            for i in range(mini(empty_slots_to_show, available.size())):
                indices.append(available[i])
    grid_container.columns = 9 if mode == "hotbar" else preferred_columns
    for child in grid_container.get_children():
        grid_container.remove_child(child)
        child.queue_free()
    for i in indices:
        var cell: InventoryCell = cells_scene.instantiate()
        grid_container.add_child(cell)
        cell.configure(inv, i, self, mode == "hotbar", backpack)
        cell.refresh()
    var actual_stacks: int = inv.size() - available.size()
    var item_count: int = 0
    for i in range(inv.size()):
        var stack: InvSlot = inv.slot_at(i)
        item_count += stack.count if stack != null else 0
    counter.text = ("%d/%d stacks  |  %d items" % [actual_stacks, inv.size(), item_count]) if mode != "hotbar" else "QUICK ACCESS"
    visible_count.text = "%d entries / %d units" % [occupied.size(), shown_quantity] if mode != "hotbar" else "Linked; physical stock in backpack"
    $Layout/SearchBar.visible = mode != "hotbar"
    sort_button.visible = mode != "hotbar"
    $Layout/Actions/Save.visible = mode != "hotbar"
    $Layout/Actions/Load.visible = mode != "hotbar"
    filter_button.visible = mode != "hotbar"

func request_use(item: InvItem) -> void:
    if item != null and backpack != null and backpack.has(item):
        use_requested.emit(item)

func message(value: String) -> void:
    info.text = value
    feedback.emit(value)

func request_world_drop(origin: Inv, origin_index: int, item: InvItem, viewport_position: Vector2) -> void:
    if item != null:
        world_drop_requested.emit(origin, origin_index, item, viewport_position)
