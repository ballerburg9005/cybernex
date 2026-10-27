extends SceneTree

var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://tests/InteractionCoordinateRegression.tscn")
    var world: Node2D = scene.instantiate()
    root.add_child(world)
    var camera: Camera2D = world.get_node("Camera2D")
    var target: Area2D = world.get_node("Target")
    var hit: WorldHitTest = world.get_node("WorldHitTest")
    for setup in [
        {"camera": Vector2(320, 180), "zoom": Vector2.ONE},
        {"camera": Vector2(850, 620), "zoom": Vector2.ONE},
        {"camera": Vector2(-120, 1500), "zoom": Vector2(1.7, 1.7)}
    ]:
        camera.global_position = setup["camera"]
        camera.zoom = setup["zoom"]
        camera.force_update_scroll()
        await physics_frame
        await process_frame
        var viewport_pos: Vector2 = hit.world_to_viewport(target.global_position)
        var restored: Vector2 = hit.viewport_to_world(viewport_pos)
        _check(restored.distance_to(target.global_position) < 0.02, "World-space cursor must map back to target after camera move/zoom.")
        var pick: CollisionObject2D = hit.pick_viewport_point(viewport_pos)
        _check(pick == target, "World physics hit must land on target with HUD CanvasLayer present.")
    world.queue_free()
    if failures > 0:
        push_error("%d COORDINATE CHECKS FAILED" % failures)
        quit(1)
    else:
        print("COORDINATE TESTS PASSED")
        quit(0)

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
