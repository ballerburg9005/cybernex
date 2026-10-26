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
