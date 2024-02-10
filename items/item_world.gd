@tool
extends StaticBody2D

@export var itemslot : InvSlot

@export var disabled = false
@export var only_players = true

@export var in_drag_space = false

var mytype = "item"


var old_collision_layer = 0
var old_influence_collision_mask = 0
var old_collision_shape


func set_in_drag_space(value):
	if value == "UI":
		$influence.monitoring = false
		$influence.monitorable	 = false
		collision_layer = 0
		collision_mask = 0
		set_collision_layer_value(30, true)
		set_collision_mask_value(31, true)	# inventory UI
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
		$CollisionShape2D.shape.radius = 1
		in_drag_space = true
	elif value == "world":
		set_collision_layer_value(29, true)
		set_collision_mask_value(31, true)	# inventory UI
		$influence.set_collision_mask_value(21, true) # floor
		$influence.set_collision_mask_value(7, true) # objects
		$influence.set_collision_mask_value(5, true) # terminals/switches
		$influence.set_collision_mask_value(10, false) # player collision
		$influence.set_collision_mask_value(12, true) # player hitbox
		$influence.set_collision_mask_value(16, true) # enemy hitbox
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
		$CollisionShape2D.shape.radius = 1
		in_drag_space = true
	else:
		collision_layer = old_collision_layer
		$influence.collision_mask = old_influence_collision_mask
		$CollisionShape2D.shape = old_collision_shape
		in_drag_space = false	

func _ready():
	if not itemslot:
		itemslot = InvSlot.new(preload("res://items/missing.tres"))
	$Sprite2D.texture = itemslot.item.texture
	
	old_collision_layer = collision_layer
	old_influence_collision_mask = $influence.collision_mask
	old_collision_shape = $CollisionShape2D.shape

func activate(caller):
	if caller.has_method("add_inventory_item"):
		if caller.add_inventory_item(itemslot):
			get_node("/root/main").p("Picked up "+itemslot.item.name+".")
			_on_influence_body_shape_exited(null, caller, null, null)
			queue_free()
		else:
			print("can't add item!")

func _on_influence_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	if not disabled:
		var combinables = get_node("/root/main").player.combinables
		if in_drag_space and not combinables.has([self, body]):
			if body.is_visible_in_tree():
				combinables.append([self, body])
		elif not (only_players and not "is_player" in body):
			if "activatables" in body:
				body.activatables.append(self)
				$Sprite2D.material = ShaderMaterial.new()
				$Sprite2D.material.shader = load("res://assets/shaders/outline.gdshader")
				$Sprite2D.material.set_shader_parameter("add_margins", false)


func _on_influence_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	if in_drag_space:
		if not (body is TileMap and $influence.get_overlapping_bodies().filter(func(e): return e is TileMap).size() > 0):
			get_node("/root/main").player.combinables = get_node("/root/main").player.combinables.filter(func(e): return not (e.has(self) and e.has(body)))
		
	if "activatables" in body and body.activatables.has(self):
		body.activatables.erase(self)
		$Sprite2D.material.shader = null
