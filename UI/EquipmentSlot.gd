extends Button
class_name EquipmentSlot

@export_enum("weapon_primary", "weapon_secondary", "augment_head", "augment_torso",
    "augment_left_arm", "augment_right_arm", "augment_legs", "augment_neural") var slot_id: String = "augment_head"

var loadout: EquipmentLoadout
var backpack: Inv
var owner_panel: Control

func setup(equipment: EquipmentLoadout, inventory: Inv, panel: Control) -> void:
    loadout = equipment
    backpack = inventory
    owner_panel = panel
    update_display()

func update_display() -> void:
    var item: InvItem = loadout.item_at(slot_id) if loadout != null else null
    text = (item.short_name if not item.short_name.is_empty() else item.name) if item != null else slot_id.replace("_", " ").to_upper()
    icon = item.texture if item != null else null
    expand_icon = true
    icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tooltip_text = (item.name + "\n" + item.description) if item != null else ("EQUIP: " + slot_id.replace("_", " "))
    modulate = Color("#d4eee9") if item != null else Color("#92a7bd")

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    if loadout == null or backpack == null or not (data is Dictionary):
        return false
    if data.get("kind", "") != "inventory_item" and data.get("kind", "") != "equipped_item":
        return false
    return loadout.can_assign(slot_id, data.get("item"), backpack)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    if not _can_drop_data(_at_position, data):
        return
    var item: InvItem = data.get("item")
    if not loadout.assign(slot_id, item, backpack):
        return
    if data.get("kind", "") == "equipped_item" and data.get("slot", "") != slot_id:
        loadout.assign(data["slot"], null, backpack)
    if owner_panel != null and owner_panel.has_method("message"):
        owner_panel.message("Equipped %s to %s." % [item.name, slot_id])

func _get_drag_data(_at_position: Vector2) -> Variant:
    if loadout == null:
        return null
    var item: InvItem = loadout.item_at(slot_id)
    if item == null:
        return null
    var label := Label.new()
    label.text = "EQUIPPED: " + item.name
    set_drag_preview(label)
    return {"kind": "equipped_item", "item": item, "slot": slot_id, "loadout": loadout}
