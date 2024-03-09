@tool
extends MarginContainer

enum Trilean {FALSE, UNKNOWN, TRUE}
@export var my_varrrr := Trilean.UNKNOWN

@export var value : float
@export_enum("default", "false", "true") var disallow_rotate: String = "default"
var no_rotate
@export_enum("default", "false", "true") var disallow_drag: String = "default"
var no_drag
@export_enum("0", "90", "180", "270") var rotate: String = "0"


@export var component : Component
var in_drag_space = false
var pre_drag_space = false

var dragged_item
var dragged_item_offset = Vector2(0,0)
var mouse_position_node

var inv : Inv

var disabled = false

var myname 

var idx = 0

var is_world = false

var timer_update := Timer.new()

var mouse_when_pressed = Vector2(0,0)

var NORMAL_SIZE = Vector2(16,16)
var SCALE = 3

var oversized = Vector2(1,1)
var relay_to_node

var zones = ["left", "top", "right", "bottom"]

func _ready():
	idx = int(name.substr(13))

	no_rotate = component.no_rotate if disallow_rotate == "default" else false if disallow_rotate == "false" else true
	no_drag = component.no_drag if disallow_drag == "default" else false if disallow_rotate == "false" else true
	
	if not component:
		component = preload("res://UI/components/missing.tres")

	if disabled or in_drag_space:
		$TextureRect.texture = preload("res://UI/components/blank.tres").texture
	else:
		$TextureRect.texture = component.texture
	
	if component not in [preload("res://UI/components/blank.tres")]:
		myname = component.name
	
	$TextureRect.stretch_mode = TextureRect.STRETCH_SCALE
	$TextureRect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	$TextureRect.custom_minimum_size = Vector2(48, 48)
	
	var mytext
	match component.short_name:
		"transistor":
			mytext = "pnp" if component.pnp else "npn"
		"wire":
			if component.is_input:
				mytext = str(value)+"V IN"
			elif component.is_output:
				mytext = "OUT"
		"resistor":
			if not (disabled or in_drag_space):
				var image = component.texture.get_image()
				var ctn = 0
				for val in [int(str(value).left(1)), int(str(value).left(2).right(1)), int(str(int(value)).length())-2, 10]:
					var rect = Rect2i(Vector2(ctn*32,0), Vector2(32, 16))
					var image_band = preload("res://UI/resistor_color_atlas.tres").get_image()
					resistor_image_modify_color(image_band, val)
					image.blend_rect(image_band, rect, Vector2.ZERO)
					ctn += 1
				$TextureRect.texture = ImageTexture.create_from_image(image)


	$TextureRect/PanelContainer.visible = true if not in_drag_space else false
	if mytext:
		$TextureRect/PanelContainer.visible = true
		$TextureRect/PanelContainer/MarginContainer/Label.text = str(mytext)
	else:
		$TextureRect/PanelContainer.visible = false
		
	if is_world:
		$influence.set_collision_mask_value(30, false)
		$influence.set_collision_mask_value(29, true)

	rotate_component(rotate)
	oversize()
	
	if Engine.is_editor_hint():
		if not timer_update.is_inside_tree():
			timer_update.one_shot = true
			timer_update.timeout.connect(_ready)
			add_child(timer_update)
		#timer_update.start(0.5)
	
	call_deferred("_started")

func _started():
	if not get_node("/root").has_node("MousePosition"):
		mouse_position_node = Control.new()
		mouse_position_node.name = "MousePosition"
		mouse_position_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_position_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		#get_node("/root/").call_deferred("add_child", mouse_position_node)
		get_node("/root/").add_child(mouse_position_node)
	else:
		mouse_position_node = get_node("/root/MousePosition")

func resistor_image_modify_color(img, val):
	var color = Color(0,0,0,0)
	match val:
		0: color = Color(0,0,0,1)
		1: color = Color(0.5,0.25,0,1)
		2: color = Color(1,0,0,1)
		3: color = Color(1,0.5,0,1)
		4: color = Color(1,1,0,1)
		5: color = Color(0,1,0,1)
		6: color = Color(0,0,1,1)
		7: color = Color(0.5,0,0.5,1)
		8: color = Color(0.5,0.5,0.5,1)
		9: color = Color(1,1,1,1)
		10: color = Color(0.75,0.65,0.25,1)
		11: color = Color(0.8,0.8,0.8,1)

	for y in range(img.get_height()):
		for x in range(img.get_width()):
			img.set_pixel(x, y, img.get_pixel(x, y) * color)

func oversize():
	var component_size = NORMAL_SIZE
	if component.texture:
		component_size = component.texture.get_size()
		if rotate in ["90", "270"]:
			component_size = Vector2(component_size.y, component_size.x)
		
	var margin = NORMAL_SIZE - component_size
	add_theme_constant_override("margin_right", margin.x*SCALE)
	add_theme_constant_override("margin_bottom", margin.y*SCALE)
	$TextureRect.custom_minimum_size = component_size*SCALE
	
	$influence/CollisionShape2D.shape = RectangleShape2D.new()
	$influence/CollisionShape2D.shape.size = component_size*SCALE
	
	$influence.position = component_size*SCALE*0.5
	#$left.position = Vector2(0, component_size.y*SCALE*0.5)
	#$top.position = Vector2(component_size.x*SCALE*0.5, 0)
	#$right.position = Vector2(component_size.x*SCALE, component_size.y*SCALE*0.5)
	#$bottom.position = Vector2(component_size.x*SCALE*0.5, component_size.y*SCALE)
	
	
func rotate_component(a = null):
	if $TextureRect.texture:
		rotate = str((int(rotate)+90)%360) if not a else str(int(a))
		var image = $TextureRect.texture.get_image()
		for i in range(0, int(int(rotate)/90.0)):
			image.rotate_90(CLOCKWISE)
		if not in_drag_space:
			$TextureRect.texture = ImageTexture.create_from_image(image)
			
	oversize()

func get_rotated_connections():
	var rotate_map = {  "0": {"left": "left", "top": "top", "right": "right", "bottom": "bottom"},
					"90": {"left": "top", "top": "right", "right": "bottom", "bottom": "left"},
					"180": {"left": "right", "top": "bottom", "right": "left", "bottom": "top"},
					"270": {"left": "bottom", "top": "left", "right": "top", "bottom": "right"},
				}
	var out = {}
	for dir in component.connections:
		var out_arr = component.connections[dir].duplicate()
		if (rotate == "90" and dir in ["left", "right"]) or (rotate == "180") or (rotate == "270" and dir in ["top", "bottom"]):
			out_arr.reverse()
		out[rotate_map[rotate][dir]] = out_arr
	return out


func _on_focus_entered():
	if relay_to_node:
		return relay_to_node._on_focus_entered()
	$TextureRect.material = ShaderMaterial.new()
	$TextureRect.material.shader = preload("res://assets/shaders/outline.gdshader")
	$TextureRect.material.set_shader_parameter("add_margins", false)


func _on_focus_exited():
	if relay_to_node:
		return relay_to_node._on_focus_exited()
	$TextureRect.material.shader = null


func _on_gui_input(event):
	if relay_to_node:
		relay_to_node._on_gui_input(event)
		return true
		
	if not disabled:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_when_pressed = get_local_mouse_position()
				pre_drag_space = true
			elif not event.pressed:
				if pre_drag_space:
					if not no_rotate:
						rotate_component()
				in_drag_space = false
				pre_drag_space = false
				dragged_item = null
				_ready()
		else:
			if pre_drag_space and abs(mouse_when_pressed.x - get_local_mouse_position().x) + abs(mouse_when_pressed.y - get_local_mouse_position().y) > 3:
				if not no_drag:
					in_drag_space = true
					pre_drag_space = false
					# instantiate new
					dragged_item = duplicate()
					dragged_item_offset = get_local_mouse_position()
					get_node("/root/CircuitPuzzle").add_child(dragged_item)
					_ready()
			
			#get_node("/root/main").player.drag_inventory_item(self, Vector2(0,0)) #custom_minimum_size*0.5


func _input(event):
	if dragged_item:
		dragged_item.position = mouse_position_node.get_local_mouse_position()-dragged_item_offset
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				pass

func _on_area_shape_entered(area_rid, area, area_shape_index, local_shape_index):
	if relay_to_node:
		relay_to_node._on_area_shape_entered(area_rid, area, area_shape_index, local_shape_index)
		return true
		
	if is_visible_in_tree():
		#get_node("/root/main").player.combinables.append([self, body])
		pass

func _on_area_shape_exited(area_rid, area, area_shape_index, local_shape_index):
	if relay_to_node:
		relay_to_node._on_area_shape_exited(area_rid, area, area_shape_index, local_shape_index)
		return true
	pass
	#get_node("/root/main").player.combinables.erase([self, body])
