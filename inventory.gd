extends Resource
class_name Inv

## Author slot capacity and contents in Inspector. All mutations use methods;
## they emit 'changed' rather than asking UI nodes to poll or invoke _ready().
signal changed

@export var items: Array[InvSlot] = []
@export_range(1, 100000, 1) var max_stack: int = 999

func _init(slots: int = 9) -> void:
    if items.is_empty():
        for i in range(maxi(slots, 0)):
            items.append(InvSlot.new())

func size() -> int:
    return items.size()

func _valid(slot: InvSlot) -> bool:
    return slot != null and slot.occupied()

func count(item: InvItem = null) -> int:
    var total: int = 0
    for slot in items:
        if _valid(slot) and (item == null or slot.item == item):
            total += slot.count
    return total

func has(item: InvItem, quantity: int = 1) -> bool:
    return item != null and count(item) >= quantity

func find(item: InvItem) -> int:
    for i in range(items.size()):
        if _valid(items[i]) and items[i].item == item:
            return i
    return -1

func ensure_slots() -> void:
    for i in range(items.size()):
        if items[i] == null:
            items[i] = InvSlot.new()

func normalize() -> void:
    # Zero and placeholder cells are empty; identical item resources merge.
    # Piles are allowed to span multiple cells when exceeding max_stack.
    ensure_slots()
    var state: Array[Dictionary] = _state()
    var by_item: Array[InvItem] = []
    var totals: Array[int] = []
    for cell in state:
        var part: InvItem = cell["item"]
        var amount: int = cell["count"]
        if part == null or amount <= 0:
            continue
        var idx: int = by_item.find(part)
        if idx == -1:
            by_item.append(part)
            totals.append(amount)
        else:
            totals[idx] += amount
    var out: Array[Dictionary] = []
    for i in range(items.size()):
        out.append({"item": null, "count": 0})
    var write: int = 0
    for i in range(by_item.size()):
        var remaining: int = totals[i]
        while remaining > 0 and write < out.size():
            var amount: int = mini(remaining, maxi(max_stack, 1))
            out[write] = {"item": by_item[i], "count": amount}
            remaining -= amount
            write += 1
    _commit(out)

func sort_by_category() -> void:
    normalize()
    var stacks: Array[Dictionary] = []
    for cell in _state():
        if cell["item"] != null and cell["count"] > 0:
            stacks.append(cell)
    stacks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if a["item"].type == b["item"].type:
            return a["item"].name.to_lower() < b["item"].name.to_lower()
        return a["item"].type < b["item"].type
    )
    var out: Array[Dictionary] = []
    for cell in stacks:
        out.append(cell)
    while out.size() < items.size():
        out.append({"item": null, "count": 0})
    _commit(out)

func can_add(item: InvItem, amount: int) -> bool:
    return _put(_state(), item, amount, -1)

func add_item(item: InvItem, amount: int = 1, preferred_index: int = -1) -> bool:
    var state: Array[Dictionary] = _state()
    if not _put(state, item, amount, preferred_index):
        return false
    _commit(state)
    return true

func remove_item(item: InvItem, amount: int = 1) -> bool:
    if amount < 1 or count(item) < amount:
        return false
    var state: Array[Dictionary] = _state()
    var left: int = amount
    for i in range(state.size()):
        if state[i]["item"] == item:
            var used: int = mini(left, int(state[i]["count"]))
            state[i]["count"] -= used
            left -= used
            if state[i]["count"] <= 0:
                state[i] = {"item": null, "count": 0}
            if left == 0:
                break
    _commit(state)
    return true

func slot_at(index: int) -> InvSlot:
    if index < 0 or index >= items.size() or not _valid(items[index]):
        return null
    return items[index]

func _state() -> Array[Dictionary]:
    var state: Array[Dictionary] = []
    for slot in items:
        state.append({
            "item": slot.item if _valid(slot) else null,
            "count": slot.count if _valid(slot) else 0
        })
    return state

func _commit(state: Array[Dictionary]) -> void:
    assert(state.size() == items.size())
    for i in range(state.size()):
        var item: InvItem = state[i]["item"]
        var quantity: int = int(state[i]["count"])
        items[i] = InvSlot.new(item, quantity) if item != null and quantity > 0 else InvSlot.new()
    changed.emit()

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
        if state[i]["item"] == item:
            var room: int = maxi(0, max_stack - int(state[i]["count"]))
            var put: int = mini(remaining, room)
            state[i]["count"] += put
            remaining -= put
    for i in order:
        if remaining <= 0:
            break
        if state[i]["item"] == null:
            var put: int = mini(remaining, maxi(max_stack, 1))
            state[i] = {"item": item, "count": put}
            remaining -= put
    return remaining == 0

## Old World pickups still use InvSlot; no references to source stacks escape.
func add_stack(stack: InvSlot, preferred_index: int = -1) -> bool:
    return stack != null and add_item(stack.item, stack.count, preferred_index)
