extends SceneTree

var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error(reason)

func _run() -> void:
    var main_scene: PackedScene = load("res://main.tscn")
    check(main_scene != null, "Overworld should parse.")
    if main_scene == null:
        quit(1)
        return
    var game: Control = main_scene.instantiate()
    root.add_child(game)
    var item: InvItem = load("res://items/wires.tres")
    var player = game.get_node("World/Player")
    var world: Node2D = game.get_node("World")
    var picker: WorldHitTest = world.get_node("WorldHitTest")
    check(picker.reference_physics_body == player, "World hover picker must reference actual player physics canvas.")
    var viewport_point: Vector2 = picker.world_to_viewport(player.global_position)
    check(picker.viewport_to_world(viewport_point).distance_to(player.global_position) < 0.1, "World hover projection must invert Camera2D canvas transforms on original map.")
    var quantity: int = player.inventory.count(item)
    check(quantity >= 2, "Starter inventory should contain wires for world drops.")
    var screen_point: Vector2 = world.get_global_transform_with_canvas() * player.global_position + Vector2(30, 0)
    var old_children: int = world.get_child_count()
    game.mouse_over_ui = false
    game._handle_world_drop(player.inventory, player.inventory.find(item), item, screen_point)
    check(player.inventory.count(item) == quantity - 1, "World drop should remove exactly one wire from stack.")
    check(world.get_child_count() == old_children + 1, "One world object should be instantiated (no shadow HUD clone).")
    var created: Node = world.get_child(world.get_child_count() - 1)
    check(created.get("itemslot") != null and created.get("itemslot").count == 1, "Dropped world pickup carries exactly one physical item.")
    created.activate(player)
    check(player.inventory.count(item) == quantity, "Picking up the dropped object must restore its original count.")
    game.mouse_over_ui = true
    game._handle_world_drop(player.inventory, player.inventory.find(item), item, screen_point)
    check(player.inventory.count(item) == quantity, "Item released over UI should never be dropped on the floor.")
    game.mouse_over_ui = false
    game._handle_world_drop(player.inventory, player.inventory.find(item), item, screen_point + Vector2(900, 0))
    check(player.inventory.count(item) == quantity, "Out-of-reach world drop must preserve stock.")
    # World terminal must use the SAME physical backpack as the grid/mannequin.
    var terminal = game.get_node("World/Terminal")
    check(terminal.puzzle_type == "circuit", "Main-map terminal should offer electronic repair.")
    terminal.activate(player)
    var bench: CircuitWorkbench = terminal.ui_menu
    check(bench != null and bench.field_inventory == player.inventory, "Terminal workbench should bind actual player backpack.")
    var resistor: InvItem = load("res://items/resistor10.tres")
    var solder: InvItem = load("res://items/solder.tres")
    var resistor_before: int = player.inventory.count(resistor)
    var solder_before: int = player.inventory.count(solder)
    bench.selected_index = 1
    bench._remove_selected()
    bench.palette.select(0)
    bench._on_board_click(Vector2i(2, 1))
    check(player.inventory.count(resistor) == resistor_before - 1, "Installing physical resistor should use one real item.")
    check(player.inventory.count(solder) == solder_before - 1, "Soldering should spend exactly one solder.")
    for tick in range(15):
        bench._on_simulation_tick()
    check(terminal.access_granted, "Electrically valid repair should grant legacy map terminal access.")
    check(terminal.ui_menu == null, "Solved repair should dismiss the workbench overlay.")
    var jumper: InvItem = load("res://items/wire_bridge.tres")
    var wire_model: CircuitPart = load("res://systems/circuits/parts/wire_straight.tres")
    check(jumper.circuit_part == wire_model, "Crafted jumper is mapped to a usable real circuit part.")
    # Cut/rebuild usable electronics: world backpack recipe -> actual circuit part.
    var wires: InvItem = load("res://items/wires.tres")
    var crafted: Dictionary = InventoryOperations.move_or_combine(
        player.inventory, player.inventory.find(wires), player.inventory, player.inventory.find(solder))
    check(bool(crafted.get("ok", false)) and player.inventory.count(jumper) == 1,
        "Wire plus solder must yield a real playable circuit jumper.")
    # A separately scavenged solder segment is required to INSTALL the crafted part.
    player.inventory.add_item(solder, 1)
    var second: CircuitWorkbench = load("res://systems/circuits/CircuitWorkbench.tscn").instantiate()
    game.get_node("HUD").add_child(second)
    second.set_field_inventory(player.inventory)
    second.palette.select(1)
    second._on_board_click(Vector2i(4, 0))
    check(player.inventory.count(jumper) == 0 and second.board.placement_at(Vector2i(4, 0)) >= 0,
        "Crafted jumper should be consumed as an actual editable wire component.")
    check(player.inventory.count(solder) == 0, "Installing crafted jumper must additionally consume solder.")
    second.queue_free()
    game.queue_free()
    if failures == 0:
        print("WORLD INVENTORY TESTS PASSED")
        quit(0)
    else:
        push_error("%d WORLD INVENTORY TESTS FAILED" % failures)
        quit(1)
