extends Button
class_name InventoryCell

var inventory: Inv
var backpack: Inv
var index: int = -1
var is_hotbar: bool = false
var parent_view: Control

@onready var image: TextureRect = $Icon
@onready var number: Label = $Count

func configure(model: Inv, cell_index: int, view: Control, hotbar: bool = false, owner_inventory: Inv = null) -> void:
    inventory = model
    backpack = owner_inventory if owner_inventory != null else model
    index = cell_index
    parent_view = view
    is_hotbar = hotbar
    if is_node_ready():
        refresh()

func refresh() -> void:
    if not is_node_ready():
        return
    var cell: InvSlot = inventory.slot_at(index) if inventory != null else null
    var amount: int = backpack.count(cell.item) if is_hotbar and cell != null else cell.count if cell != null else 0
    if cell == null or amount <= 0:
        image.texture = null
        number.text = ""
        tooltip_text = "Empty slot"
        return
    image.texture = cell.item.texture
    number.text = "×%d" % amount if amount > 1 else ""
    tooltip_text = "%s   ×%d\n%s" % [cell.item.name, amount, cell.item.description]

func _get_drag_data(_at_position: Vector2) -> Variant:
    if inventory == null:
        return null
    var stack: InvSlot = inventory.slot_at(index)
    if stack == null or (is_hotbar and backpack.count(stack.item) <= 0):
        return null
    var preview := HBoxContainer.new()
    var icon_preview := TextureRect.new()
    icon_preview.texture = stack.item.texture
    icon_preview.custom_minimum_size = Vector2(36, 36)
    icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.add_child(icon_preview)
    var label := Label.new()
    label.text = stack.item.name
    preview.add_child(label)
    set_drag_preview(preview)
    return {
        "kind": "inventory_item", "item": stack.item,
        "inventory": inventory, "index": index, "hotbar": is_hotbar
    }

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    if not (data is Dictionary) or inventory == null:
        return false
    return data.get("kind", "") in ["inventory_item", "equipped_item"]

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    if not _can_drop_data(_at_position, data):
        return
    var kind: String = data.get("kind", "")
    if kind == "equipped_item":
        var loadout: EquipmentLoadout = data.get("loadout")
        if loadout != null:
            loadout.assign(str(data.get("slot", "")), null, backpack)
            _feedback("Unequipped item; still in backpack.")
        return
    var origin: Inv = data.get("inventory")
    var item: InvItem = data.get("item")
    if item == null or origin == null:
        return
    if is_hotbar:
        # A hotbar is a reference, not a duplicated stack.
        inventory.items[index] = InvSlot.new(item, 1)
        inventory.changed.emit()
        _feedback("Assigned %s to quick slot %d." % [item.name, index + 1])
        return
    if bool(data.get("hotbar", false)):
        # Dragging quickslot onto backpack removes only quick binding.
        var origin_idx: int = int(data.get("index", -1))
        if origin_idx >= 0 and origin_idx < origin.size():
            origin.items[origin_idx] = InvSlot.new()
            origin.changed.emit()
        _feedback("Quickslot cleared. Items remain in backpack.")
        return
    var outcome: Dictionary = InventoryOperations.move_or_combine(origin, int(data.get("index", -1)), inventory, index)
    _feedback(str(outcome.get("message", "")))

func _feedback(message: String) -> void:
    if parent_view != null and parent_view.has_method("message"):
        parent_view.message(message)
