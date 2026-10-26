extends Resource
class_name Inv

## One authoritative model for all views. Every write stages and validates
## the full stock list before emitting changed: no partial pickups or recipes.
@export var items: Array[InvSlot] = []
@export_range(1, 100000, 1) var max_stack: int = 999
@export var auto_group_stacks: bool = true

func _init(slots: int = 9) -> void:
    if items.is_empty():
        for i in range(maxi(slots, 0)):
            items.append(InvSlot.new())

static func item_key(item: InvItem) -> String:
    if item == null:
        return ""
    if not item.item_id.is_empty():
        return "item:" + item.item_id
    if not item.resource_path.is_empty():
        return "path:" + item.resource_path
    return "instance:" + str(item.get_instance_id())

static func matches(a: InvItem, b: InvItem) -> bool:
    return a != null and b != null and item_key(a) == item_key(b)

func size() -> int:
    return items.size()

func _valid(slot: InvSlot) -> bool:
    return slot != null and slot.occupied()

func count(item: InvItem = null) -> int:
    var total: int = 0
    for slot in items:
        if _valid(slot) and (item == null or matches(slot.item, item)):
            total += slot.count
    return total

func has(item: InvItem, quantity: int = 1) -> bool:
    return item != null and quantity >= 1 and count(item) >= quantity

func find(item: InvItem) -> int:
    for i in range(items.size()):
        if _valid(items[i]) and matches(items[i].item, item):
            return i
    return -1

func ensure_slots() -> void:
    var modified: bool = false
    for i in range(items.size()):
        if items[i] == null:
            items[i] = InvSlot.new()
            modified = true
    if modified:
        emit_changed()

func normalize() -> bool:
    # Explicit normalization always merges, even if auto_group_stacks=false.
    return _commit(_state(), true, true)

func sort_by_category() -> void:
    var result: Dictionary = _packed_state(_state())
    if not result["ok"]:
        return
    var stacks: Array[Dictionary] = []
    for cell in result["state"]:
        if cell["item"] != null:
            stacks.append(cell)
    stacks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var left: InvItem = a["item"]
        var right: InvItem = b["item"]
        if left.type == right.type:
            return left.name.naturalnocasecmp_to(right.name) < 0
        return left.type < right.type
    )
    while stacks.size() < items.size():
        stacks.append(_empty())
    _commit(stacks)

func can_add(item: InvItem, amount: int) -> bool:
    var state: Array[Dictionary] = _state()
    return _put(state, item, amount, -1) and (not auto_group_stacks or _packed_state(state)["ok"])

func add_item(item: InvItem, amount: int = 1, preferred_index: int = -1) -> bool:
    var state: Array[Dictionary] = _state()
    if not _put(state, item, amount, preferred_index):
        return false
    return _commit(state)

func remove_item(item: InvItem, amount: int = 1) -> bool:
    if amount < 1 or count(item) < amount:
        return false
    var state: Array[Dictionary] = _state()
    var left: int = amount
    for i in range(state.size()):
        if matches(state[i]["item"], item):
            var used: int = mini(left, int(state[i]["count"]))
            state[i]["count"] = int(state[i]["count"]) - used
            left -= used
            if int(state[i]["count"]) <= 0:
                state[i] = _empty()
            if left == 0:
                break
    return _commit(state)

func slot_at(index: int) -> InvSlot:
    if index < 0 or index >= items.size() or not _valid(items[index]):
        return null
    return items[index]

func _state() -> Array[Dictionary]:
    var state: Array[Dictionary] = []
    for slot in items:
        state.append({"item": slot.item if _valid(slot) else null,
            "count": slot.count if _valid(slot) else 0})
    return state

static func _empty() -> Dictionary:
    return {"item": null, "count": 0}

func _packed_state(state: Array[Dictionary]) -> Dictionary:
    if state.size() != items.size():
        return {"ok": false, "state": []}
    var ordered_keys: Array[String] = []
    var totals: Dictionary = {}
    var templates: Dictionary = {}
    for cell in state:
        var item: InvItem = cell.get("item")
        var quantity: int = int(cell.get("count", 0))
        if item == null:
            if quantity > 0:
                return {"ok": false, "state": []}
            continue
        if item.type & InvItem.IS_NOT or quantity < 0:
            return {"ok": false, "state": []}
        if quantity == 0:
            continue
        var key: String = item_key(item)
        if not totals.has(key):
            ordered_keys.append(key)
            templates[key] = item
            totals[key] = 0
        totals[key] = int(totals[key]) + quantity
    var result: Array[Dictionary] = []
    for key in ordered_keys:
        var left: int = int(totals[key])
        while left > 0:
            if result.size() >= items.size():
                return {"ok": false, "state": []}
            var amount: int = mini(left, maxi(max_stack, 1))
            result.append({"item": templates[key], "count": amount})
            left -= amount
    while result.size() < items.size():
        result.append(_empty())
    return {"ok": true, "state": result}

func _commit(state: Array[Dictionary], notify: bool = true, pack: bool = true) -> bool:
    if state.size() != items.size():
        return false
    var final_state: Array[Dictionary] = state
    if pack and auto_group_stacks:
        var outcome: Dictionary = _packed_state(state)
        if not outcome["ok"]:
            return false
        final_state = outcome["state"]
    for cell in final_state:
        var item: InvItem = cell.get("item")
        var quantity: int = int(cell.get("count", 0))
        if quantity < 0 or quantity > max_stack or (quantity > 0 and item == null):
            return false
    for i in range(final_state.size()):
        var item: InvItem = final_state[i]["item"]
        var quantity: int = int(final_state[i]["count"])
        items[i] = InvSlot.new(item, quantity) if item != null and quantity > 0 else InvSlot.new()
    if notify:
        emit_changed()
    return true

func _put(state: Array[Dictionary], item: InvItem, amount: int, preferred_index: int) -> bool:
    if item == null or item.type & InvItem.IS_NOT or amount < 1:
        return false
    var remaining: int = amount
    var order: Array[int] = []
    if preferred_index >= 0 and preferred_index < state.size():
        order.append(preferred_index)
    for i in range(state.size()):
        if not order.has(i):
            order.append(i)
    for i in order:
        if matches(state[i]["item"], item):
            var room: int = maxi(0, max_stack - int(state[i]["count"]))
            var added: int = mini(remaining, room)
            state[i]["count"] = int(state[i]["count"]) + added
            remaining -= added
    for i in order:
        if remaining <= 0:
            break
        if state[i]["item"] == null:
            var added: int = mini(remaining, maxi(max_stack, 1))
            state[i] = {"item": item, "count": added}
            remaining -= added
    return remaining == 0

func add_stack(stack: InvSlot, preferred_index: int = -1) -> bool:
    return stack != null and add_item(stack.item, stack.count, preferred_index)
