@tool
extends Resource
class_name SalvageInventory

## Transactional supply accounting. Godot scene authors edit the stock in
## Inspector; runtime instances duplicate the resource before changing it.
@export var stocks: Array[SalvageStock] = []

func amount(item_id: String) -> int:
    var total: int = 0
    for stock in stocks:
        if stock != null and stock.item_id == item_id and not stock.is_tool:
            total += stock.quantity
    return total

func has_tool(item_id: String) -> bool:
    for stock in stocks:
        if stock != null and stock.item_id == item_id and stock.is_tool and stock.quantity > 0:
            return true
    return false

func missing(requirements: Array[MaterialRequirement], required_tools: PackedStringArray = PackedStringArray()) -> PackedStringArray:
    var missing_items := PackedStringArray()
    var costs: Dictionary = {}
    for req in requirements:
        if req != null:
            costs[req.item_id] = int(costs.get(req.item_id, 0)) + req.quantity
    for item_id in costs:
        if amount(item_id) < int(costs[item_id]):
            missing_items.append("%s ×%d" % [item_id, int(costs[item_id]) - amount(item_id)])
    for item_id in required_tools:
        if not has_tool(item_id):
            missing_items.append("tool: %s" % item_id)
    return missing_items

func consume(requirements: Array[MaterialRequirement], required_tools: PackedStringArray = PackedStringArray()) -> bool:
    # First verify the *whole* transaction: no partial consumption on failure.
    if not missing(requirements, required_tools).is_empty():
        return false
    var costs: Dictionary = {}
    for req in requirements:
        if req != null:
            costs[req.item_id] = int(costs.get(req.item_id, 0)) + req.quantity
    for item_id in costs:
        var remaining: int = int(costs[item_id])
        for stock in stocks:
            if stock != null and stock.item_id == item_id and not stock.is_tool:
                var used: int = mini(remaining, stock.quantity)
                stock.quantity -= used
                remaining -= used
                if remaining == 0:
                    break
        if remaining > 0:
            push_error("Inventory invariant: item exists but not as consumable: " + item_id)
            return false
    return true

func add(item_id: String, quantity: int, display_name: String = "") -> void:
    if quantity <= 0:
        return
    for stock in stocks:
        if stock != null and stock.item_id == item_id and not stock.is_tool:
            stock.quantity += quantity
            return
    var new_stock := SalvageStock.new()
    new_stock.item_id = item_id
    new_stock.display_name = display_name if not display_name.is_empty() else item_id
    new_stock.quantity = quantity
    stocks.append(new_stock)

func add_tool(item_id: String, display_name: String) -> void:
    if has_tool(item_id):
        return
    var new_stock := SalvageStock.new()
    new_stock.item_id = item_id
    new_stock.display_name = display_name
    new_stock.is_tool = true
    new_stock.quantity = 1
    stocks.append(new_stock)

func describe() -> String:
    var lines := PackedStringArray()
    for stock in stocks:
        if stock != null and stock.quantity > 0:
            var suffix: String = " (tool)" if stock.is_tool else ""
            lines.append("%s: %d%s" % [stock.display_name, stock.quantity, suffix])
    return "\n".join(lines)

func snapshot() -> Dictionary:
    var entries: Array[Dictionary] = []
    for stock in stocks:
        if stock != null:
            entries.append({
                "id": stock.item_id, "name": stock.display_name,
                "quantity": stock.quantity, "is_tool": stock.is_tool
            })
    return {"entries": entries}

func restore(data: Dictionary) -> void:
    stocks.clear()
    for entry in data.get("entries", []):
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var stock := SalvageStock.new()
        stock.item_id = str(entry.get("id", ""))
        stock.display_name = str(entry.get("name", stock.item_id))
        stock.quantity = maxi(0, int(entry.get("quantity", 0)))
        stock.is_tool = bool(entry.get("is_tool", false))
        stocks.append(stock)
