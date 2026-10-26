extends SceneTree

## Actual camera-projected drag gestures onto original map physics objects.
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func _run() -> void:
    var game: Control = load("res://main.tscn").instantiate()
    root.add_child(game)
    var world: Node2D = game.get_node("World")
    var player: CharacterBody2D = game.get_node("World/Player")
    var picker: WorldHitTest = game.get_node("World/WorldHitTest")
    var wall: StaticBody2D = game.get_node("World/Object")
    var cutters: InvItem = load("res://items/side_cutters.tres")
    var wires: InvItem = load("res://items/wires.tres")
    check(wall.mysubtype == "wirewall", "Legacy exposed wall must still be an authored interactive wire source.")
    player.global_position = wall.global_position + Vector2(-30, 0)
    await physics_frame
    var wall_viewport: Vector2 = picker.world_to_viewport(wall.global_position)
    check(picker.pick_viewport_point(wall_viewport) == wall, "Camera-projected world query should hit exposed wall collider.")
    var previous_wires: int = player.inventory.count(wires)
    var previous_cutters: int = player.inventory.count(cutters)
    var previous_remaining: int = wall.howoften
    var original_pickups: int = _pickup_count(world)
    game.mouse_over_ui = true # A stale hover flag after beginning a UI drag.
    game._handle_world_drop(player.inventory, player.inventory.find(cutters), cutters, wall_viewport)
    check(wall.howoften == previous_remaining - 1, "Cutter drag onto exposed wall must use physical wire source once.")
    check(player.inventory.count(cutters) == previous_cutters, "Reusable pliers must never be consumed on the wall.")
    check(player.inventory.count(wires) == previous_wires, "Salvage must appear in world before actual pickup, not as free inventory.")
    check(_pickup_count(world) == original_pickups + 1, "Exposed wall must release exactly one genuine world pickup.")
    var saved: Dictionary = WorldSave.capture(game)
    wall.howoften = previous_remaining
    check(WorldSave.restore(game, saved), "Physical salvage state must roundtrip through world save.")
    check(wall.howoften == previous_remaining - 1, "World save must not regenerate wall salvage.")
    var enemy: CharacterBody2D = game.get_node("World/Enemy")
    player.global_position = enemy.global_position + Vector2(-35, 0)
    await physics_frame
    var health_before: float = enemy.health
    var robot_viewport: Vector2 = picker.world_to_viewport(enemy.global_position)
    check(picker.pick_viewport_point(robot_viewport) != null, "World picker must resolve robot body or robot hitbox.")
    game._handle_world_drop(player.inventory, player.inventory.find(cutters), cutters, robot_viewport)
    check(enemy.health < health_before and enemy.health > health_before - 3.0,
        "Dragging pliers onto robot must deal real but limited mechanical damage.")
    check(player.inventory.count(cutters) == previous_cutters, "A melee tool cannot vanish after a strike.")
    game.queue_free()
    if failures == 0:
        print("WORLD INTERACTION TESTS PASSED")
        quit(0)
    else:
        push_error("%d WORLD INTERACTION TESTS FAILED" % failures)
        quit(1)

func _pickup_count(world: Node2D) -> int:
    var amount: int = 0
    for child in world.get_children():
        if child is WorldItemPickup:
            amount += 1
    return amount
