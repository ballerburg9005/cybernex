extends Node2D
class_name ArcFlash

## Short, deliberately visible engineering arc. A thin luminous flash and
## procedural sparks; uses no arbitrary filtered/resized external textures.
## World renders it at the project's authored 3x integer scale.
var bolt: Line2D

func burst(end_global: Vector2) -> void:
    bolt = Line2D.new()
    bolt.width = 3.0
    bolt.default_color = Color("#8de7ff")
    bolt.joint_mode = Line2D.LINE_JOINT_ROUND
    bolt.begin_cap_mode = Line2D.LINE_CAP_ROUND
    bolt.end_cap_mode = Line2D.LINE_CAP_ROUND
    bolt.add_point(Vector2.ZERO)
    var local_end: Vector2 = to_local(end_global)
    var vec: Vector2 = local_end.normalized()
    var perp: Vector2 = Vector2(-vec.y, vec.x)
    # One angular kink makes the discharge readable even at short distances.
    bolt.add_point(local_end * 0.49 + perp * minf(6.0, local_end.length() * 0.12))
    bolt.add_point(local_end)
    add_child(bolt)

    var sparks := CPUParticles2D.new()
    sparks.position = local_end
    sparks.amount = 15
    sparks.lifetime = 0.24
    sparks.one_shot = true
    sparks.explosiveness = 1.0
    sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
    sparks.spread = 180.0
    sparks.gravity = Vector2.ZERO
    sparks.initial_velocity_min = 25.0
    sparks.initial_velocity_max = 70.0
    sparks.scale_amount_min = 1.0
    sparks.scale_amount_max = 2.5
    sparks.color = Color("#a0dfff")
    add_child(sparks)
    sparks.emitting = true
    var tween := create_tween()
    tween.tween_property(bolt, "modulate:a", 0.0, 0.27)
    tween.tween_callback(queue_free)
