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
    var valid_type: bool = bool(item.type & InvItem.IS_WEAPON) if slot_id.begins_with("weapon_") else bool(item.type & InvItem.IS_AUGMENTATION)
    if not valid_type or not item.equipment_slots.has(slot_id):
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

func can_relocate(from_id: String, to_id: String, backpack: Inv) -> bool:
    if from_id == to_id:
        return true
    var current: InvItem = item_at(from_id)
    if current == null or backpack == null or not SOCKETS.has(to_id):
        return false
    var allowed: bool = bool(current.type & InvItem.IS_WEAPON) if to_id.begins_with("weapon_") else bool(current.type & InvItem.IS_AUGMENTATION)
    if not allowed or not current.equipment_slots.has(to_id):
        return false
    var destination: InvItem = item_at(to_id)
    if destination == current:
        return true
    # Swapping gear retains any displaced item in the backpack.
    var elsewhere: int = 0
    for socket in SOCKETS:
        if socket != from_id and socket != to_id and item_at(socket) == current:
            elsewhere += 1
    return backpack.count(current) > elsewhere

func relocate(from_id: String, to_id: String, backpack: Inv) -> bool:
    if not can_relocate(from_id, to_id, backpack):
        return false
    if from_id == to_id:
        return true
    var current: InvItem = item_at(from_id)
    set(from_id, null)
    set(to_id, current)
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
        var valid_type: bool = bool(item.type & InvItem.IS_WEAPON) if key.begins_with("weapon_") else bool(item.type & InvItem.IS_AUGMENTATION)
        if not valid_type or not item.equipment_slots.has(key) or backpack.count(item) <= assigned:
            set(key, null)
            modified = true
        else:
            usage[item] = assigned + 1
    if modified:
        emit_changed()

func occupied_sockets() -> int:
    var total: int = 0
    for key in SOCKETS:
        if item_at(key) != null:
            total += 1
    return total

func snapshot() -> Dictionary:
    var state: Dictionary = {}
    for key in SOCKETS:
        var item: InvItem = item_at(key)
        state[key] = Inv.item_key(item)
    return state

func restore(state: Dictionary, backpack: Inv) -> bool:
    if backpack == null:
        return false
    var planned: Dictionary = {}
    var totals: Dictionary = {}
    for key in SOCKETS:
        var id: String = str(state.get(key, ""))
        var item: InvItem = null
        if not id.is_empty():
            for stack in backpack.items:
                if stack != null and stack.occupied() and Inv.item_key(stack.item) == id:
                    item = stack.item
                    break
            if item == null:
                return false
            var allowed: bool = bool(item.type & InvItem.IS_WEAPON) if key.begins_with("weapon_") else bool(item.type & InvItem.IS_AUGMENTATION)
            if not allowed or not item.equipment_slots.has(key):
                return false
            totals[id] = int(totals.get(id, 0)) + 1
            if backpack.count(item) < int(totals[id]):
                return false
        planned[key] = item
    for key in SOCKETS:
        set(key, planned[key])
    emit_changed()
    return true
