@tool
extends StaticBody2D

## Only genuine world-space pickups belong in the physics simulation.
## Inventory previews are Controls; never duplicate this body into a CanvasLayer.
@export var itemslot: InvSlot
@export var disabled: bool = false
@export var only_players: bool = true

var mytype: String = "item"
var myname: String = "Item"

func _ready() -> void:
    if itemslot == null or not itemslot.occupied():
        itemslot = InvSlot.new(preload("res://items/missing.tres"), 1)
    $Sprite2D.texture = itemslot.item.texture
    myname = itemslot.item.name

func activate(caller: Node) -> void:
    if disabled or itemslot == null or not itemslot.occupied():
        return
    if caller == null or not caller.has_method("add_inventory_item"):
        return
    # A pickup transfers an entire authored stack, or none of it on overflow.
    if caller.add_inventory_item(itemslot):
        var main: Node = get_node_or_null("/root/main")
        if main != null and main.has_method("p"):
            main.p("Picked up %s ×%d." % [itemslot.item.name, itemslot.count])
        queue_free()

func _on_influence_body_shape_entered(_rid: RID, body: Node2D, _body_shape_index: int, _local_shape_index: int) -> void:
    if disabled or body == null:
        return
    if only_players and not ("is_player" in body):
        return
    if "activatables" in body and not body.activatables.has(self):
        body.activatables.append(self)
        $Sprite2D.material = ShaderMaterial.new()
        $Sprite2D.material.shader = preload("res://assets/shaders/outline.gdshader")
        $Sprite2D.material.set_shader_parameter("add_margins", false)

func _on_influence_body_shape_exited(_rid: RID, body: Node2D, _body_shape_index: int, _local_shape_index: int) -> void:
    if body != null and "activatables" in body:
        body.activatables.erase(self)
    $Sprite2D.material = null
