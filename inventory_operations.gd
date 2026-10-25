extends RefCounted
class_name InventoryOperations

## Pure, staged transaction logic. No scene nodes, physics Areas, or nested
## _ready() calls. Never mutates ingredients unless output can fit.
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
        # Recipes work in either orientation; useful when tools are dragged second.
        recipe = _recipe(target.item, origin.item)
        if recipe != null:
            return _craft(source, from_index, destination, to_index, recipe, true)
    var a: Array[Dictionary] = source._state()
    var b: Array[Dictionary] = a if source == destination else destination._state()
    var item: InvItem = a[from_index]["item"]
    var quantity: int = int(a[from_index]["count"])
    if b[to_index]["item"] == item:
        var transfer: int = mini(quantity, maxi(0, destination.max_stack - int(b[to_index]["count"])))
        if transfer <= 0:
            return _fail("Stack full")
        b[to_index]["count"] += transfer
        a[from_index]["count"] -= transfer
        if a[from_index]["count"] <= 0:
            a[from_index] = _empty()
    elif b[to_index]["item"] == null:
        var transfer: int = mini(quantity, destination.max_stack)
        b[to_index] = {"item": item, "count": transfer}
        a[from_index]["count"] -= transfer
        if a[from_index]["count"] <= 0:
            a[from_index] = _empty()
    elif source == destination:
        var previous: Dictionary = b[to_index]
        b[to_index] = a[from_index]
        a[from_index] = previous
    else:
        return _fail("Target occupied by a different item")
    source._commit(a)
    if source != destination:
        destination._commit(b)
    return {"ok": true, "message": "Moved"}

static func _recipe(from: InvItem, to: InvItem) -> InvCombo:
    if from == null or to == null:
        return null
    for recipe in from.combos:
        if recipe != null and recipe.with == to:
            return recipe
    return null

static func _craft(source: Inv, from_index: int, target: Inv, to_index: int, recipe: InvCombo, reversed: bool) -> Dictionary:
    var a: Array[Dictionary] = source._state()
    var b: Array[Dictionary] = a if source == target else target._state()
    var first: Dictionary = a[from_index]
    var second: Dictionary = b[to_index]
    var from_cost: int = (recipe.target_amount if reversed else recipe.source_amount) if (recipe.eats_target if reversed else recipe.eats_source) else 0
    var to_cost: int = (recipe.source_amount if reversed else recipe.target_amount) if (recipe.eats_source if reversed else recipe.eats_target) else 0
    if int(first["count"]) < from_cost or int(second["count"]) < to_cost:
        return _fail("Not enough ingredients")
    first["count"] -= from_cost
    second["count"] -= to_cost
    if first["count"] <= 0:
        a[from_index] = _empty()
    if second["count"] <= 0:
        b[to_index] = _empty()
    if recipe.yields != null and not (recipe.yields.type & InvItem.IS_NOT) and recipe.amount > 0:
        if not target._put(b, recipe.yields, recipe.amount, to_index):
            return _fail("No space for crafted output; nothing consumed")
    source._commit(a)
    if source != target:
        target._commit(b)
    return {
        "ok": true, "message": "Crafted %s ×%d" % [recipe.yields.name if recipe.yields != null else "result", recipe.amount],
        "crafted": recipe.yields, "amount": recipe.amount
    }

static func _empty() -> Dictionary:
    return {"item": null, "count": 0}

static func _fail(message: String) -> Dictionary:
    return {"ok": false, "message": message}
