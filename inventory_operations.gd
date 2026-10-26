extends RefCounted
class_name InventoryOperations

## Slot-targeted Godot drag transactions. Source and destination state are
## staged separately; successful recipes emit changes only AFTER both commit.
static func move_or_combine(source: Inv, from_index: int, destination: Inv, to_index: int) -> Dictionary:
    if source == null or destination == null:
        return _fail("Invalid inventory")
    var origin: InvSlot = source.slot_at(from_index)
    if origin == null or to_index < 0 or to_index >= destination.size():
        return _fail("Invalid source or target slot")
    if source == destination and from_index == to_index:
        return _fail("Same slot")
    var target: InvSlot = destination.slot_at(to_index)
    if target != null:
        var recipe: InvCombo = _recipe(origin.item, target.item)
        if recipe != null:
            return _craft(source, from_index, destination, to_index, recipe, false)
        recipe = _recipe(target.item, origin.item)
        if recipe != null:
            return _craft(source, from_index, destination, to_index, recipe, true)
    var a: Array[Dictionary] = source._state()
    var b: Array[Dictionary] = a if source == destination else destination._state()
    var item: InvItem = a[from_index]["item"]
    var quantity: int = int(a[from_index]["count"])
    if Inv.matches(b[to_index]["item"], item):
        var transfer: int = mini(quantity, maxi(0, destination.max_stack - int(b[to_index]["count"])))
        if transfer <= 0:
            return _fail("Stack full")
        b[to_index]["count"] = int(b[to_index]["count"]) + transfer
        a[from_index]["count"] = int(a[from_index]["count"]) - transfer
        if a[from_index]["count"] <= 0:
            a[from_index] = _empty()
    elif b[to_index]["item"] == null:
        var transfer: int = mini(quantity, destination.max_stack)
        b[to_index] = {"item": item, "count": transfer}
        a[from_index]["count"] = int(a[from_index]["count"]) - transfer
        if a[from_index]["count"] <= 0:
            a[from_index] = _empty()
    elif source == destination:
        var previous: Dictionary = b[to_index]
        b[to_index] = a[from_index]
        a[from_index] = previous
    else:
        # Moving between containers may exchange whole piles if each fits.
        if int(b[to_index]["count"]) > source.max_stack or int(a[from_index]["count"]) > destination.max_stack:
            return _fail("Swapped stack exceeds container capacity")
        var previous: Dictionary = b[to_index]
        b[to_index] = a[from_index]
        a[from_index] = previous
    if not _commit_both(source, a, destination, b):
        return _fail("Inventory full; movement cancelled")
    return {"ok": true, "message": "Moved"}

static func _recipe(from: InvItem, to: InvItem) -> InvCombo:
    if from == null or to == null:
        return null
    for recipe in from.combos:
        if recipe != null and Inv.matches(recipe.with, to):
            return recipe
    return null

static func _craft(source: Inv, from_index: int, target: Inv, to_index: int, recipe: InvCombo, reversed: bool) -> Dictionary:
    if recipe.yields == null or recipe.yields.type & InvItem.IS_NOT or recipe.amount < 1:
        return _fail("Recipe has no valid usable output")
    var a: Array[Dictionary] = source._state()
    var b: Array[Dictionary] = a if source == target else target._state()
    var from_item: InvItem = a[from_index]["item"]
    var to_item: InvItem = b[to_index]["item"]
    var from_cost: int = (recipe.target_amount if reversed else recipe.source_amount) if (recipe.eats_target if reversed else recipe.eats_source) else 0
    var to_cost: int = (recipe.source_amount if reversed else recipe.target_amount) if (recipe.eats_source if reversed else recipe.eats_target) else 0
    if not _take(a, from_item, from_cost, from_index):
        return _fail("Not enough %s" % from_item.name)
    if not _take(b, to_item, to_cost, to_index):
        return _fail("Not enough %s" % to_item.name)
    if not target._put(b, recipe.yields, recipe.amount, to_index):
        return _fail("No space for crafted output; nothing consumed")
    if not _commit_both(source, a, target, b):
        return _fail("Inventory full; crafting cancelled")
    return {"ok": true, "message": "Crafted %s ×%d" % [recipe.yields.name, recipe.amount],
        "crafted": recipe.yields, "amount": recipe.amount}

static func _take(state: Array[Dictionary], item: InvItem, amount: int, preferred_index: int) -> bool:
    if amount <= 0:
        return true
    var remaining: int = amount
    var order: Array[int] = [preferred_index]
    for i in range(state.size()):
        if i != preferred_index:
            order.append(i)
    for index in order:
        if not Inv.matches(state[index]["item"], item):
            continue
        var consumed: int = mini(remaining, int(state[index]["count"]))
        state[index]["count"] = int(state[index]["count"]) - consumed
        remaining -= consumed
        if int(state[index]["count"]) <= 0:
            state[index] = _empty()
        if remaining == 0:
            return true
    return false

static func _commit_both(source: Inv, a: Array[Dictionary], target: Inv, b: Array[Dictionary]) -> bool:
    # Preflight both packed layouts BEFORE making either inventory observable.
    var first: Array[Dictionary] = a
    var second: Array[Dictionary] = b
    if source.auto_group_stacks:
        var packed_a: Dictionary = source._packed_state(a)
        if not packed_a["ok"]:
            return false
        first = packed_a["state"]
    if source != target and target.auto_group_stacks:
        var packed_b: Dictionary = target._packed_state(b)
        if not packed_b["ok"]:
            return false
        second = packed_b["state"]
    if not source._commit(first, false, false):
        return false
    if source != target and not target._commit(second, false, false):
        return false
    source.emit_changed()
    if source != target:
        target.emit_changed()
    return true

static func _empty() -> Dictionary:
    return {"item": null, "count": 0}

static func _fail(message: String) -> Dictionary:
    return {"ok": false, "message": message}
