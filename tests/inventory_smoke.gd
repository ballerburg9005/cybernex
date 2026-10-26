extends SceneTree

## Godot 4.7: godot --headless --path . --script res://tests/inventory_smoke.gd
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, why: String) -> void:
    if not ok:
        failures += 1
        push_error(why)

func _run() -> void:
    test_auto_stacks()
    test_recipes()
    test_recipe_atomicity()
    test_loadout_counts()
    test_hud_and_mannequin()
    test_auto_grouping_after_transactions()
    test_multistack_crafting_and_cross_swap()
    test_equipment_snapshot_atomicity()
    test_search_filter_count()
    test_crafting_index()
    if failures != 0:
        push_error("INVENTORY TESTS FAILED: " + str(failures))
        quit(1)
    else:
        print("INVENTORY TESTS PASSED")
        quit(0)

func item(path: String) -> InvItem:
    return load("res://items/" + path + ".tres")

func test_auto_stacks() -> void:
    var bag := Inv.new(6)
    var wires: InvItem = item("wires")
    check(bag.add_item(wires, 3), "First stock pickup must succeed.")
    check(bag.add_item(wires, 4), "Second stock pickup must stack automatically.")
    check(bag.count(wires) == 7, "count() must sum quantities instead of number of slots.")
    check(bag.find(wires) == 0, "Same resource stacks use first existing position.")
    check(bag.remove_item(wires, 2), "Taking two from a seven stack should work.")
    check(bag.count(wires) == 5, "Taking two must leave five.")
    bag.items[1] = InvSlot.new(wires, 8)
    bag.normalize()
    check(bag.count(wires) == 13, "Normalize must merge duplicate persisted stacks without loss.")
    check(bag.slot_at(0).count == 13 and bag.slot_at(1) == null, "Normalize must compact equal stacks.")
    check(bag.count() == 13, "Total inventory count should sum quantities.")
    bag.max_stack = 5
    bag.normalize()
    check(bag.count(wires) == 13 and bag.slot_at(0).count == 5 and bag.slot_at(1).count == 5 and bag.slot_at(2).count == 3, "Stack limit should split piles and conserve total stock.")
    var tiny := Inv.new(2)
    tiny.max_stack = 2
    check(not tiny.add_item(wires, 5), "Overflowing fixed capacity must fail.")
    check(tiny.count(wires) == 0, "Full-inventory rejection must be atomic.")

func test_recipes() -> void:
    var cutters: InvItem = item("side_cutters")
    var cable: InvItem = item("big_wire")
    var wires: InvItem = item("wires")
    var solder: InvItem = item("solder")
    var bridge: InvItem = item("wire_bridge")
    var bag := Inv.new(8)
    check(bag.add_item(cutters, 1), "Tool must fit.")
    check(bag.add_item(cable, 1), "Cable must fit.")
    var result: Dictionary = InventoryOperations.move_or_combine(bag, bag.find(cutters), bag, bag.find(cable))
    check(bool(result["ok"]), "Cutters + cable should use authored resource recipe.")
    check(bag.count(cable) == 0, "Heavy cable must be consumed exactly once.")
    check(bag.count(cutters) == 1, "Tool must remain.")
    check(bag.count(wires) == 3, "Cutters yield three real, usable wires, not junk.")
    check(bag.add_item(solder, 1), "Solder must fit.")
    result = InventoryOperations.move_or_combine(bag, bag.find(solder), bag, bag.find(wires))
    check(bool(result["ok"]), "Solder dragged onto wire must match reverse recipe.")
    check(bag.count(bridge) == 1, "Combination should yield a usable jumper.")
    check(bag.count(solder) == 0 and bag.count(wires) == 2, "Combining must spend exactly one solder and one wire.")
    var other := Inv.new(3)
    check(other.add_item(cable, 1), "Other inventory may hold cable.")
    result = InventoryOperations.move_or_combine(bag, bag.find(cutters), other, other.find(cable))
    check(bool(result["ok"]) and other.count(wires) == 3, "Cross-inventory recipe output stays in destination and consumes source/tool correctly.")
    check(bag.count(cutters) == 1, "Cross-inventory craft cannot consume reusable tool.")

func test_recipe_atomicity() -> void:
    var catalyst := InvItem.new()
    catalyst.name = "catalyst"
    var scrap := InvItem.new()
    scrap.name = "scrap"
    var recipe := InvCombo.new()
    recipe.with = scrap
    recipe.yields = item("wire_bridge")
    recipe.eats_source = false
    recipe.eats_target = false
    catalyst.combos.append(recipe)
    var full := Inv.new(2)
    full.items[0] = InvSlot.new(catalyst, 1)
    full.items[1] = InvSlot.new(scrap, 1)
    var result: Dictionary = InventoryOperations.move_or_combine(full, 0, full, 1)
    check(not bool(result["ok"]), "Recipe that cannot fit output must fail.")
    check(full.count(catalyst) == 1 and full.count(scrap) == 1, "No part of failed craft may consume stock.")
    # Two stacks of identical items merge instead of calling a ghost recipe.
    var piles := Inv.new(3)
    piles.items[0] = InvSlot.new(item("wires"), 2)
    piles.items[1] = InvSlot.new(item("wires"), 3)
    result = InventoryOperations.move_or_combine(piles, 1, piles, 0)
    check(bool(result["ok"]) and piles.count(item("wires")) == 5, "Dragging identical stacks should merge without changing item totals.")
    check(piles.slot_at(0).count == 5 and piles.slot_at(1) == null, "Merged pile stays at target.")

func test_loadout_counts() -> void:
    var pistol: InvItem = item("arc_pistol")
    var regulator: InvItem = item("neural_regulator")
    var bag := Inv.new(6)
    bag.add_item(pistol)
    bag.add_item(regulator)
    var body := EquipmentLoadout.new()
    check(body.assign("weapon_primary", pistol, bag), "Weapon should equip to hand.")
    check(not body.assign("weapon_secondary", pistol, bag), "One pistol cannot occupy two weapon sockets.")
    check(bag.count(pistol) == 1, "Equipment references backpack stock rather than duplicating it.")
    bag.add_item(pistol)
    check(body.assign("weapon_secondary", pistol, bag), "Two identical pistols can occupy two hands.")
    check(not body.assign("augment_legs", regulator, bag), "Incompatible augmentation sockets should reject item.")
    check(body.assign("augment_neural", regulator, bag), "Neural regulator should equip to neural slot.")
    bag.remove_item(pistol, 1)
    body.reconcile(bag)
    check(body.item_at("weapon_primary") != null and body.item_at("weapon_secondary") == null, "Equipment should unequip unsupported duplicate after item loss.")
    check(body.relocate("weapon_primary", "weapon_secondary", bag), "A lone pistol must be movable between compatible hands.")
    check(body.item_at("weapon_primary") == null and body.item_at("weapon_secondary") == pistol, "Relocation should move reference, never clone an equipped copy.")
    bag.remove_item(regulator, 1)
    body.reconcile(bag)
    check(body.item_at("augment_neural") == null, "Lost augmentation must not remain equipped.")

func test_hud_and_mannequin() -> void:
    var backpack := Inv.new(12)
    var pistol: InvItem = item("arc_pistol")
    backpack.add_item(pistol, 2)
    var panel: InventoryView = load("res://UI/Inventory.tscn").instantiate()
    root.add_child(panel)
    panel.configure(backpack)
    check(panel.grid_container.get_child_count() > 1, "Inventory should render item cells and spare slots.")
    var quick := Inv.new(9)
    var quickpanel: InventoryView = load("res://UI/Inventory.tscn").instantiate()
    root.add_child(quickpanel)
    quickpanel.configure(quick, backpack, "hotbar")
    var data: Dictionary = {"kind": "inventory_item", "item": pistol, "inventory": backpack, "index": backpack.find(pistol), "hotbar": false}
    var cell: InventoryCell = quickpanel.grid_container.get_child(2)
    cell._drop_data(Vector2.ZERO, data)
    check(quick.slot_at(2) != null and backpack.count(pistol) == 2, "Quickbar linking must not double or consume stock.")
    var mannequin: EquipmentMannequin = load("res://UI/EquipmentMannequin.tscn").instantiate()
    root.add_child(mannequin)
    var loadout := EquipmentLoadout.new()
    mannequin.setup(backpack, loadout)
    var socket: EquipmentSlot = mannequin.get_node("Frame/Layout/Canvas/WeaponPrimary")
    check(socket._can_drop_data(Vector2.ZERO, data), "Godot mannequin slot should accept compatible inventory drag.")
    socket._drop_data(Vector2.ZERO, data)
    check(loadout.item_at("weapon_primary") == pistol and backpack.count(pistol) == 2, "Mannequin should equip without creating another pile.")
    backpack.remove_item(pistol, 2)
    check(quick.slot_at(2) == null, "Quickbar should expire when underlying stack reaches zero.")
    check(loadout.item_at("weapon_primary") == null, "Mannequin should clear sockets when stock disappears.")
    panel.queue_free()
    quickpanel.queue_free()
    mannequin.queue_free()

func test_auto_grouping_after_transactions() -> void:
    var wires: InvItem = item("wires")
    var other := InvItem.new()
    other.name = "Equivalent copper wire"
    other.item_id = wires.item_id
    var bag := Inv.new(7)
    bag.items[0] = InvSlot.new(wires, 2)
    bag.items[3] = InvSlot.new(other, 3)
    check(bag.add_item(wires, 1), "Adding stock should re-group duplicate stacks.")
    check(bag.count(wires) == 6 and bag.count(other) == 6, "Matching item IDs must conserve combined quantities.")
    check(bag.slot_at(0).count == 6 and bag.slot_at(1) == null, "Ungrouped saved stacks should compact automatically after any inventory write.")
    var other_cable: InvItem = item("big_wire")
    check(bag.add_item(other_cable, 2), "Different item should occupy a second stack.")
    var moving: Dictionary = InventoryOperations.move_or_combine(bag, bag.find(other_cable), bag, 6)
    check(bool(moving["ok"]), "Dragging item into an empty slot must succeed even with auto-grouping.")
    check(bag.count(other_cable) == 2, "Auto-grouping after drag must conserve moved quantities.")
    check(bag.find(other_cable) >= 0, "Moved item must remain indexed.")

func test_multistack_crafting_and_cross_swap() -> void:
    var raw: InvItem = item("wires")
    var jumper: InvItem = item("wire_bridge")
    var tool := InvItem.new()
    tool.name = "Binding jig"
    tool.item_id = "binding_jig"
    var combination := InvCombo.new()
    combination.with = raw
    combination.yields = jumper
    combination.amount = 2
    combination.eats_source = false
    combination.eats_target = true
    combination.target_amount = 3
    tool.combos.append(combination)
    var bag := Inv.new(8)
    bag.max_stack = 2
    check(bag.add_item(raw, 4), "Two stacks of wire should fit.")
    check(bag.add_item(tool, 1), "Reusable jig must fit.")
    var result: Dictionary = InventoryOperations.move_or_combine(bag, bag.find(tool), bag, bag.find(raw))
    check(bool(result["ok"]), "Quantity-three recipe must consume wires from multiple two-item piles.")
    check(bag.count(raw) == 1 and bag.count(jumper) == 2 and bag.count(tool) == 1, "Pooled multi-stack recipe must conserve and yield correct quantities.")
    var first := Inv.new(3)
    var second := Inv.new(3)
    var pistol: InvItem = item("arc_pistol")
    var regulator: InvItem = item("neural_regulator")
    first.add_item(pistol, 1)
    second.add_item(regulator, 1)
    result = InventoryOperations.move_or_combine(first, first.find(pistol), second, second.find(regulator))
    check(bool(result["ok"]) and first.count(regulator) == 1 and second.count(pistol) == 1, "Occupied cross-inventory drag should swap whole stacks safely.")
    var previous: int = second.count(pistol)
    first.max_stack = 1
    second.add_item(pistol, 2)
    result = InventoryOperations.move_or_combine(second, second.find(pistol), first, first.find(regulator))
    check(not result["ok"], "Incompatible cross-container stack size must reject a swap.")
    check(second.count(pistol) == previous + 2 and first.count(regulator) == 1, "Rejected cross-inventory swap must conserve both original piles.")

func test_equipment_snapshot_atomicity() -> void:
    var pistol: InvItem = item("arc_pistol")
    var arm: InvItem = item("servo_brace")
    var backpack := Inv.new(8)
    backpack.add_item(pistol, 1)
    backpack.add_item(arm, 1)
    var body := EquipmentLoadout.new()
    check(body.assign("weapon_primary", pistol, backpack), "Equip pistol before snapshot.")
    check(body.assign("augment_left_arm", arm, backpack), "Equip servo before snapshot.")
    var snap: Dictionary = body.snapshot()
    var restored := EquipmentLoadout.new()
    check(restored.restore(snap, backpack), "Valid loadout save must roundtrip.")
    check(restored.item_at("weapon_primary") == pistol and restored.item_at("augment_left_arm") == arm, "Roundtrip loadout preserves both socket references.")
    snap["weapon_secondary"] = Inv.item_key(pistol)
    check(not restored.restore(snap, backpack), "A single pistol cannot be restored into two weapon sockets.")
    check(restored.item_at("weapon_secondary") == null and restored.item_at("weapon_primary") == pistol, "Invalid restore must leave previous valid loadout intact.")
    snap["weapon_secondary"] = ""
    snap["augment_head"] = Inv.item_key(pistol)
    check(not restored.restore(snap, backpack), "Weapon cannot restore into augmentation socket.")

func test_search_filter_count() -> void:
    var bag := Inv.new(6)
    var wire: InvItem = item("wires")
    var pistol: InvItem = item("arc_pistol")
    bag.add_item(wire, 4)
    bag.add_item(pistol, 2)
    var index: InventoryView = load("res://UI/Inventory.tscn").instantiate()
    root.add_child(index)
    index.configure(bag)
    check(index.counter.text.contains("6 items"), "Inventory total must count units, not occupied slots.")
    index.search_input.text = "arc"
    index.refresh()
    check(index.visible_count.text == "1 entries / 2 units", "Search should filter the index without changing physical stock.")
    check(bag.count(wire) == 4 and bag.count(pistol) == 2, "Filtering must not mutate the underlying inventory.")
    index.search_input.text = ""
    index.refresh()
    check(index.visible_count.text == "2 entries / 6 units", "Clearing search must restore complete grouped counts.")
    index.queue_free()

func test_crafting_index() -> void:
    var bag := Inv.new(12)
    var cutters: InvItem = item("side_cutters")
    var heavy: InvItem = item("big_wire")
    var wires: InvItem = item("wires")
    bag.add_item(cutters, 1)
    var discovered: Array[Dictionary] = InventoryRecipeIndex.list_for(bag)
    check(discovered.size() >= 1, "Owning a tool should reveal Inspector-authored recovery recipes.")
    check(not bool(discovered[0]["can_craft"]), "Recipe index must report missing copper stock before crafting.")
    bag.add_item(heavy, 1)
    var panel: InventoryView = load("res://UI/Inventory.tscn").instantiate()
    root.add_child(panel)
    panel.configure(bag)
    var candidate: int = -1
    for i in range(panel.offered_recipes.size()):
        var entry: Dictionary = panel.offered_recipes[i]
        if Inv.matches(entry["source"], cutters) and Inv.matches(entry["target"], heavy):
            candidate = i
            break
    check(candidate >= 0, "Inventory crafting bar should list tool + cable.")
    if candidate >= 0:
        check(panel.offered_recipes[candidate]["can_craft"], "Recipe must be available once the material is present.")
        panel.recipe_selector.select(candidate)
        panel._assemble_selected()
        check(bag.count(heavy) == 0 and bag.count(wires) == 3 and bag.count(cutters) == 1, "Assembly bar must use atomic crafting, consuming material but not tools.")
    panel.queue_free()
