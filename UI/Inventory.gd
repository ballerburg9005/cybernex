extends PanelContainer
class_name InventoryView

## One inventory is the source of truth. Change signals rebuild only visible
## controls, replacing 200ms polling and per-cell physics collisions.
signal feedback(message: String)
signal use_requested(item: InvItem)
signal save_requested
signal load_requested
signal world_drop_requested(origin: Inv, origin_index: int, item: InvItem, viewport_position: Vector2, amount: int)
@export var inv: Inv
@export_enum("backpack", "hotbar") var mode: String = "backpack"
@export_range(1, 12, 1) var preferred_columns: int = 10
@export_range(1, 20, 1) var empty_slots_to_show: int = 10

@onready var grid_container: GridContainer = $Layout/Scroll/GridContainer
@onready var counter: Label = $Layout/Toolbar/Counter
@onready var filter_button: OptionButton = $Layout/Actions/Filter
@onready var sort_button: Button = $Layout/Actions/Sort
@onready var search_input: LineEdit = $Layout/SearchBar/Search
@onready var visible_count: Label = $Layout/SearchBar/VisibleCount
@onready var info: Label = $Layout/Feedback
@onready var recipe_selector: OptionButton = $Layout/Crafting/Recipes
@onready var assemble_button: Button = $Layout/Crafting/Craft
var offered_recipes: Array[Dictionary] = []

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
    assemble_button.pressed.connect(_assemble_selected)
    recipe_selector.item_selected.connect(func(index: int) -> void:
        assemble_button.disabled = index < 0 or index >= offered_recipes.size() or not bool(offered_recipes[index]["can_craft"])
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
        inv.ensure_slots() # Do not compact the player’s carefully positioned stacks.
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
        if filtering == 0:
            for i in range(inv.size()):
                indices.append(i) # Preserve physical slot indexes and gaps.
        else:
            indices.append_array(occupied)
    grid_container.columns = 10
    var visible_rows: int = maxi(1, floori(maxf(48.0, $Layout/Scroll.size.y - 12.0) / 50.0))
    if mode != "hotbar":
        while indices.size() < maxi(50, visible_rows * 10):
            indices.append(-1)
    if mode != "hotbar":
        while indices.size() % 10 != 0:
            indices.append(-1)
    for child in grid_container.get_children():
        grid_container.remove_child(child)
        child.queue_free()
    for i in indices:
        var cell: InventoryCell = cells_scene.instantiate()
        grid_container.add_child(cell)
        cell.configure(inv, i, self, mode == "hotbar", backpack)
        cell.refresh()
        if i == -1:
            cell.disabled = true
            cell.modulate = Color("#858b91")
    var actual_stacks: int = inv.size() - available.size()
    var item_count: int = 0
    for i in range(inv.size()):
        var stack: InvSlot = inv.slot_at(i)
        item_count += stack.count if stack != null else 0
    counter.text = ("%d/%d stacks  |  %d items" % [actual_stacks, inv.size(), item_count]) if mode != "hotbar" else ""
    visible_count.text = "%d entries / %d units" % [occupied.size(), shown_quantity] if mode != "hotbar" else "Linked; physical stock in backpack"
    # Crafting is intentionally discovered by dragging physical ingredients.
    # The legacy programmatic controls remain for authoring/tests only.
    $Layout/Toolbar.visible = false
    $Layout/Actions.visible = false
    $Layout/SearchBar.visible = false
    $Layout/Crafting.visible = false
    $Layout/Feedback.visible = false

func request_use(item: InvItem) -> void:
    if item != null and backpack != null and backpack.has(item):
        use_requested.emit(item)

func message(value: String) -> void:
    # Only the original lower-right event feed narrates gameplay.
    feedback.emit(value)

func request_world_drop(origin: Inv, origin_index: int, item: InvItem, viewport_position: Vector2, amount: int = 1) -> void:
    if item != null:
        world_drop_requested.emit(origin, origin_index, item, viewport_position, amount)

func _refresh_recipe_index() -> void:
    var retained_id: String = ""
    var prior: int = recipe_selector.selected
    if prior >= 0 and prior < offered_recipes.size():
        retained_id = str(offered_recipes[prior]["id"])
    offered_recipes = InventoryRecipeIndex.list_for(inv)
    recipe_selector.clear()
    if offered_recipes.is_empty():
        recipe_selector.add_item("NO KNOWN COMBINATIONS")
        recipe_selector.set_item_disabled(0, true)
        assemble_button.disabled = true
        return
    var selected: int = 0
    for i in range(offered_recipes.size()):
        var entry: Dictionary = offered_recipes[i]
        recipe_selector.add_item(entry["label"])
        recipe_selector.set_item_disabled(i, not bool(entry["can_craft"]))
        if str(entry["id"]) == retained_id:
            selected = i
    recipe_selector.select(selected)
    assemble_button.disabled = not bool(offered_recipes[selected]["can_craft"])

func _assemble_selected() -> void:
    var index: int = recipe_selector.selected
    if mode == "hotbar" or inv == null or index < 0 or index >= offered_recipes.size():
        return
    var entry: Dictionary = offered_recipes[index]
    var from_index: int = inv.find(entry["source"])
    var to_index: int = inv.find(entry["target"])
    if from_index < 0 or to_index < 0 or from_index == to_index:
        message("Required ingredients are not in distinct inventory stacks.")
        return
    var outcome: Dictionary = InventoryOperations.move_or_combine(inv, from_index, inv, to_index)
    message(str(outcome.get("message", "No usable result.")))
