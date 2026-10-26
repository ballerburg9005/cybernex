extends Node2D
class_name WorldHitTest

## Place as a child of World, never of a HUD CanvasLayer.
## UI and world must never share physics Areas merely to drag inventory.
@export_flags_2d_physics var interactable_layers: int = 49264
@export var reference_physics_body: PhysicsBody2D

func viewport_to_world(viewport_position: Vector2) -> Vector2:
    # Both points stay in one Viewport; invert the CAMERA / WORLD canvas,
    # not a Control's CanvasLayer transform.
    return get_canvas_transform().affine_inverse() * viewport_position

func world_to_viewport(world_position: Vector2) -> Vector2:
    return get_canvas_transform() * world_position

func pick_at_mouse() -> CollisionObject2D:
    return pick_world_point(get_global_mouse_position())

func pick_viewport_point(viewport_position: Vector2) -> CollisionObject2D:
    return pick_world_point(viewport_to_world(viewport_position))

func pick_world_point(point: Vector2) -> CollisionObject2D:
    var query := PhysicsPointQueryParameters2D.new()
    query.position = point
    query.collide_with_bodies = true
    query.collide_with_areas = true
    query.collision_mask = interactable_layers
    if reference_physics_body != null:
        query.canvas_instance_id = PhysicsServer2D.body_get_canvas_instance_id(reference_physics_body.get_rid())
    var results: Array[Dictionary] = get_world_2d().direct_space_state.intersect_point(query, 32)
    for result in results:
        var collider: CollisionObject2D = result["collider"]
        if collider != null and collider.is_visible_in_tree():
            return collider
    return null
