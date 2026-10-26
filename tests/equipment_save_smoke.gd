extends SceneTree

## End-to-end saved-world, powered-augmentation and tool tests.
## Godot 4.7.2 --headless --path . --script res://tests/equipment_save_smoke.gd
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _run() -> void:
    test_equipment_power()
    test_world_save()
    if failures == 0:
        print("EQUIPMENT + SAVE TESTS PASSED")
        quit(0)
    else:
        push_error("EQUIPMENT + SAVE TESTS FAILED: %d" % failures)
        quit(1)

func test_equipment_power() -> void:
    var pack := Inv.new(9)
    var loadout := EquipmentLoadout.new()
    var runtime := EquipmentRuntime.new()
    var servo: InvItem = load("res://items/servo_brace.tres")
    var neural: InvItem = load("res://items/neural_regulator.tres")
    var pistol: InvItem = load("res://items/arc_pistol.tres")
    var cell: InvItem = load("res://items/power_cell.tres")
    check(pack.add_item(servo), "Servo equipment stock should fit.")
    check(pack.add_item(neural), "Neural equipment stock should fit.")
    check(pack.add_item(pistol), "Arc tool should fit.")
    check(loadout.assign("augment_left_arm", servo, pack), "Power limb servo.")
    check(loadout.assign("augment_neural", neural, pack), "Power neural diagnostic implant.")
    check(loadout.assign("weapon_primary", pistol, pack), "Equip low-power arc tool.")
    check(runtime.locomotion_multiplier(loadout, pack) > 1.1, "Powered servo should improve movement.")
    check(runtime.diagnostic_level(loadout, pack) == 2, "Neural regulator should unlock advanced diagnostics.")
    check(runtime.service_reach_bonus(loadout, pack) >= 30.0, "Servo should extend maintenance reach.")
    var charged: float = runtime.charge_wh
    runtime.tick(120.0, loadout, pack)
    check(runtime.charge_wh < charged, "Powered augmentations must consume energy over time.")
    var shot: Dictionary = runtime.try_discharge(loadout, pack)
    check(shot.get("ok", false) and float(shot.get("range", 0)) >= 140, "Equipped arc tool should discharge with range and power cost.")
    check(not runtime.try_discharge(loadout, pack)["ok"], "Immediate rapid discharges must be rate limited.")
    runtime.tick(1.0, loadout, pack)
    check(runtime.try_discharge(loadout, pack)["ok"], "Arc tool should reset once electrical coil recovers.")
    runtime.charge_wh = 0.0
    check(runtime.locomotion_multiplier(loadout, pack) == 1.0, "Depleted suit must disable servo movement bonus.")
    check(runtime.diagnostic_level(loadout, pack) == 0, "Empty battery must disable neural diagnostics.")
    check(not runtime.try_discharge(loadout, pack)["ok"], "Empty suit must not fire weapon.")
    check(pack.add_item(cell, 2), "Recovered power cells should fit.")
    check(runtime.recharge(cell, pack), "A real owned power cell must restore charge.")
    check(runtime.charge_wh > 0.0 and pack.count(cell) == 1, "Power cell use must spend exactly one.")
    var snapshot: Dictionary = runtime.snapshot()
    var duplicate := EquipmentRuntime.new()
    check(duplicate.restore(snapshot), "Equipment power snapshot must roundtrip.")
    check(absf(duplicate.charge_wh - runtime.charge_wh) < 0.00001, "Restored battery energy must be exact.")
    check(not duplicate.restore({"charge_wh": -50.0, "cooldown": 0.0}), "Corrupted negative batteries must be rejected.")

func test_world_save() -> void:
    var scene: PackedScene = load("res://main.tscn")
    var game: Control = scene.instantiate()
    root.add_child(game)
    var player = game.get_node("World/Player")
    var terminal = game.get_node("World/Terminal")
    var cell: InvItem = load("res://items/power_cell.tres")
    var wires: InvItem = load("res://items/wires.tres")
    var pistol: InvItem = load("res://items/arc_pistol.tres")
    check(player.inventory.count(cell) >= 2, "Authored starting stock should include charge cells.")
    player.health = 43.0
    player.position = Vector2(223.0, 182.0)
    player.equipment_runtime.charge_wh = 9.25
    player.inventory.add_item(wires, 2)
    player.equipment.assign("weapon_secondary", pistol, player.inventory) # may fail when owning only one; not essential
    terminal.access_granted = true
    var deliberate_slot: int = 41
    var split: Dictionary = InventoryOperations.move_or_combine(
        player.inventory, player.inventory.find(wires), player.inventory, deliberate_slot, 1)
    check(bool(split.get("ok", false)) and player.inventory.slot_at(deliberate_slot) != null,
        "Backpack must allow one wire to be positioned in an arbitrary distant slot.")
    var bag_count: int = player.inventory.count(wires)
    var cell_count: int = player.inventory.count(cell)
    var initial_items: int = 0
    for node in game.world.get_children():
        if node is WorldItemPickup:
            initial_items += 1
    check(game.save_game(), "Main game Save button handler must save all physical state.")
    player.inventory.remove_item(wires, 3)
    player.inventory.remove_item(cell, 1)
    player.health = 12.0
    player.position = Vector2(600.0, 350.0)
    player.equipment_runtime.charge_wh = 0.0
    terminal.access_granted = false
    check(game.load_game(), "Main game Load button handler must restore saved world.")
    check(player.inventory.count(wires) == bag_count and player.inventory.count(cell) == cell_count, "Save/load must exactly restore stacked physical stock.")
    check(player.inventory.slot_at(deliberate_slot) != null
        and Inv.matches(player.inventory.slot_at(deliberate_slot).item, wires)
        and player.inventory.slot_at(0) != null,
        "World save must restore the actual physical backpack position, not repack its contents.")
    check(player.position.distance_to(Vector2(223.0, 182.0)) < 0.01 and absf(player.health - 43.0) < 0.01, "Save/load must restore player pose and health.")
    check(absf(player.equipment_runtime.charge_wh - 9.25) < 0.001, "Save/load must restore suit energy.")
    check(terminal.access_granted, "Repair/access state must survive save/load.")
    var full_index: InventoryView = game.get_node("HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/InventoryItems")
    check(full_index.inv == player.inventory, "HUD must rebind to restored, authoritative backpack.")
    var mannequin: EquipmentMannequin = game.get_node("HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/PanelContainer/MarginContainer/Equipment")
    check(mannequin.backpack == player.inventory and mannequin.loadout == player.equipment, "Mannequin must reference freshly restored player equipment.")
    var hotbar: InventoryView = game.get_node("HUD/QuickInventory/InventoryItems")
    check(hotbar.backpack == player.inventory and hotbar.inv == player.quickinventory, "Linked quickbar must rebind without duplicating items.")
    check(game.companion_drawer.backpack_view.inv == player.inventory,
        "Body Systems companion must relink to restored physical backpack without cloning items.")
    var restored_items: int = 0
    for node in game.world.get_children():
        if node is WorldItemPickup:
            restored_items += 1
    check(restored_items == initial_items, "Saving should restore the exact number of physical loot pickups.")
    var corrupt: Dictionary = WorldSave.capture(game)
    corrupt["version"] = 999
    check(not WorldSave.restore(game, corrupt), "Future incompatible save versions must be safely rejected.")
    corrupt["version"] = 1
    corrupt["inventory"].append({"item": "res://definitely/not/an/item.tres", "count": 1})
    check(not WorldSave.restore(game, corrupt), "Unknown inventory paths must be rejected instead of loaded.")
    check(player.inventory.count(wires) == bag_count, "Rejected save must not corrupt existing backpack stock.")
    player.quickinventory.items[0] = InvSlot.new(cell, 1)
    player.quickinventory.emit_changed()
    player.equipment_runtime.charge_wh = 0.0
    var previous_cells: int = player.inventory.count(cell)
    check(player.use_quickslot(0), "Linked quickbar hotkey must activate a suit energy consumable.")
    check(player.inventory.count(cell) == previous_cells - 1 and player.equipment_runtime.charge_wh == 12.0, "Hotbar consumption must spend precisely one physical cell.")
    check(player.use_quickslot(0), "Second linked use should consume last available power cell.")
    check(player.inventory.count(cell) == previous_cells - 2, "Second quickbar use must not mint stock.")
    check(player.quickinventory.slot_at(0) == null, "Quickslot reference must expire when all power cells are gone.")
    check(not player.use_quickslot(0), "Empty linked slot must do nothing.")
    player.quickinventory.items[1] = InvSlot.new(pistol, 1)
    player.quickinventory.emit_changed()
    var before_equipment: InvItem = player.equipment.item_at("weapon_primary")
    check(not player.use_quickslot(1), "Quickbar must not automatically attach gear to body sockets.")
    check(player.equipment.item_at("weapon_primary") == before_equipment, "Only manual mannequin dragging should alter a weapon socket.")
    game.queue_free()
