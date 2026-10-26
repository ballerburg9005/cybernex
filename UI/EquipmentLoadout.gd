@tool
extends Resource
class_name EquipmentLoadout

## Equipment references owned backpack items; it does NOT create another stack.
## Multiple sockets using identical stock require at least that many copies.

@export var weapon_primary: InvItem
@export var weapon_secondary: InvItem
@export var augment_head: InvItem
@export var augment_torso: InvItem
@export var augment_left_arm: InvItem
@export var augment_right_arm: InvItem
@export var augment_legs: InvItem
@export var augment_neural: InvItem

const SOCKETS := [
    "weapon_primary", "weapon_secondary", "augment_head", "augment_torso",
    "augment_left_arm", "augment_right_arm", "augment_legs", "augment_neural"
]

func item_at(slot_id: String) -> InvItem:
    if not SOCKETS.has(slot_id):
        return null
    return get(slot_id)

func can_assign(slot_id: String, item: InvItem, backpack: Inv) -> bool:
    if not SOCKETS.has(slot_id) or backpack == null:
        return false
    if item == null:
        return true
    if not item.equipment_slots.has(slot_id):
        return false
    var occupied: int = 0
    for key in SOCKETS:
        if key != slot_id and item_at(key) == item:
            occupied += 1
    return backpack.count(item) >= occupied + 1

func assign(slot_id: String, item: InvItem, backpack: Inv) -> bool:
    if not can_assign(slot_id, item, backpack):
        return false
    set(slot_id, item)
    emit_changed()
    return true

func reconcile(backpack: Inv) -> void:
    if backpack == null:
        return
    var usage: Dictionary = {}
    var modified: bool = false
    for key in SOCKETS:
        var item: InvItem = item_at(key)
        if item == null:
            continue
        var assigned: int = int(usage.get(item, 0))
        if not item.equipment_slots.has(key) or backpack.count(item) <= assigned:
            set(key, null)
            modified = true
        else:
            usage[item] = assigned + 1
    if modified:
        emit_changed()

func snapshot() -> Dictionary:
    var state: Dictionary = {}
    for key in SOCKETS:
        var item: InvItem = item_at(key)
        state[key] = item.resource_path if item != null else ""
    return state
