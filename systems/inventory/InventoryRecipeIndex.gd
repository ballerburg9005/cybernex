extends RefCounted
class_name InventoryRecipeIndex

## Discovery is based on actually owned parts. Recipe templates live on
## InvItem Resources in the Inspector, not in this script or a magic recipe ID.
static func list_for(stock: Inv) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    if stock == null:
        return results
    var seen: Dictionary = {}
    for slot in stock.items:
        if slot == null or not slot.occupied():
            continue
        var source: InvItem = slot.item
        for recipe in source.combos:
            if recipe == null or recipe.with == null or recipe.yields == null or recipe.amount <= 0:
                continue
            if recipe.yields.type & InvItem.IS_NOT:
                continue
            var key: String = Inv.item_key(source) + "|" + Inv.item_key(recipe.with) + "|" + Inv.item_key(recipe.yields)
            if seen.has(key):
                continue
            seen[key] = true
            var source_cost: int = recipe.source_amount if recipe.eats_source else 0
            var target_cost: int = recipe.target_amount if recipe.eats_target else 0
            var have_source: int = stock.count(source)
            var have_target: int = stock.count(recipe.with)
            var required_source: int = maxi(source_cost, 1)
            var required_target: int = maxi(target_cost, 1)
            if Inv.matches(source, recipe.with):
                required_source = source_cost + target_cost
                required_target = required_source
            var can_craft: bool = have_source >= required_source and have_target >= required_target
            var requirements: String = "%s ×%d + %s ×%d" % [
                source.name, required_source, recipe.with.name, required_target]
            if not recipe.eats_source:
                requirements += " (tool retained)"
            if not recipe.eats_target:
                requirements += " (catalyst retained)"
            var info: String = "%s → %s ×%d" % [requirements, recipe.yields.name, recipe.amount]
            if not can_craft:
                var shortages := PackedStringArray()
                if have_source < required_source:
                    shortages.append("%s ×%d" % [source.name, required_source - have_source])
                if have_target < required_target and not Inv.matches(source, recipe.with):
                    shortages.append("%s ×%d" % [recipe.with.name, required_target - have_target])
                info += "   [NEEDS %s]" % ", ".join(shortages)
            results.append({
                "id": key, "label": info,
                "source": source, "target": recipe.with,
                "can_craft": can_craft, "output": recipe.yields,
                "amount": recipe.amount
            })
    results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return str(a["label"]).naturalnocasecmp_to(str(b["label"])) < 0
    )
    return results
