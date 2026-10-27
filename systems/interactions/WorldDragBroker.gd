extends Node
class_name WorldDragBroker

## Interface between HUD inventory and world interactions.
## Add this node to your main scene, assign WorldHitTest and a CanvasLayer.
## Call begin_drag(item_resource, label) on mouse-down in an inventory slot.
## No physics objects are ever cloned/reparented into the HUD.
signal dropped_on_world(payload: Resource, target: CollisionObject2D, position: Vector2)
signal dropped_nowhere(payload: Resource)

@export var world_hit_test: WorldHitTest
@export var hud_layer: CanvasLayer

var payload: Resource
var preview: PanelContainer

func begin_drag(item: Resource, label: String) -> void:
    cancel_drag()
    if item == null or hud_layer == null or world_hit_test == null:
        return
    payload = item
    preview = PanelContainer.new()
    preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var text := Label.new()
    text.text = label
    text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    preview.add_child(text)
    hud_layer.add_child(preview)
    _update_preview()

func cancel_drag() -> void:
    payload = null
    if is_instance_valid(preview):
        preview.queue_free()
    preview = null

func _process(_delta: float) -> void:
    if payload != null:
        _update_preview()

func _update_preview() -> void:
    if is_instance_valid(preview) and hud_layer != null:
        var viewport_point: Vector2 = get_viewport().get_mouse_position()
        var ui_point: Vector2 = hud_layer.get_final_transform().affine_inverse() * viewport_point
        preview.position = ui_point + Vector2(10, 10)

func _input(event: InputEvent) -> void:
    if payload == null:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        var item: Resource = payload
        # _input() coordinates are VIEWPORT coordinates. They are never
        # Control._gui_input local coordinates or world node coordinates.
        var target: CollisionObject2D = world_hit_test.pick_viewport_point(event.position)
        var world_position: Vector2 = world_hit_test.viewport_to_world(event.position)
        cancel_drag()
        if target != null:
            dropped_on_world.emit(item, target, world_position)
        else:
            dropped_nowhere.emit(item)
        get_viewport().set_input_as_handled()
