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
    game.queue_free()
    if failures == 0:
        print("WORLD INVENTORY TESTS PASSED")
        quit(0)
    else:
        push_error("%d WORLD INVENTORY TESTS FAILED" % failures)
        quit(1)
