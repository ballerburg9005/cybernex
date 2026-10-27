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
    var name_tag: String = slot_id.replace("augment_", "").replace("weapon_", "").replace("_", " ").to_upper()
    text = name_tag + ("\n" + (item.short_name if not item.short_name.is_empty() else item.name).left(9) if item != null else "")
    icon = item.texture if item != null else null
    expand_icon = false
    icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var owned: int = backpack.count(item) if item != null and backpack != null else 0
    tooltip_text = ("%s  %dx" % [item.name, owned]) if item != null else name_tag
    modulate = Color("#d4eee9") if item != null else Color("#92a7bd")

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    if loadout == null or backpack == null or not (data is Dictionary):
        return false
    if data.get("kind", "") != "inventory_item" and data.get("kind", "") != "equipped_item":
        return false
    if data.get("kind", "") == "equipped_item":
        return loadout.can_relocate(str(data.get("slot", "")), slot_id, backpack)
    return loadout.can_assign(slot_id, data.get("item"), backpack)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    if not _can_drop_data(_at_position, data):
        return
    var item: InvItem = data.get("item")
    if data.get("kind", "") == "equipped_item":
        if not loadout.relocate(str(data.get("slot", "")), slot_id, backpack):
            return
    elif not loadout.assign(slot_id, item, backpack):
        return
    if owner_panel != null and owner_panel.has_method("message"):
        owner_panel.message("Equipped %s to %s." % [item.name, slot_id])

func _get_drag_data(_at_position: Vector2) -> Variant:
    if loadout == null:
        return null
    var item: InvItem = loadout.item_at(slot_id)
    if item == null:
        return null
    var sprite := TextureRect.new()
    sprite.texture = item.texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.custom_minimum_size = Vector2(48, 48)
    sprite.size = Vector2(48, 48)
    sprite.position = -sprite.size * 0.5
    sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    sprite.z_index = 4096
    set_drag_preview(sprite)
    return {"kind": "equipped_item", "item": item, "slot": slot_id, "loadout": loadout}
