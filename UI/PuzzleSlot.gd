@tool
extends MarginContainer

@export var component : Component

@export_enum("0", "90", "180", "270") var rotate: String = "0"

var in_drag_space = false
var pre_drag_space = false

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
	
	rotate_component(rotate)
   
	var mytext
	match component.short_name:
		"transistor":
			mytext = "pnp" if component.pnp else "npn"
		"wire":
			if component.is_input:
				mytext = str(component.value)+"V IN"
			elif component.is_output:
				mytext = "OUT"


	$TextureRect/PanelContainer.visible = true if not in_drag_space else false
	if mytext:
		$TextureRect/PanelContainer.visible = true
		$TextureRect/PanelContainer/MarginContainer/Label.text = str(mytext)
	else:
		$TextureRect/PanelContainer.visible = false
		
	if is_world:
		$influence.set_collision_mask_value(30, false)
		$influence.set_collision_mask_value(29, true)
		
	oversize()
	
	if Engine.is_editor_hint():
		if not timer_update.is_inside_tree():
			timer_update.one_shot = true
			timer_update.timeout.connect(_ready)
			add_child(timer_update)
		timer_update.start(0.5)


func oversize():
	if component.texture:
		var margin = NORMAL_SIZE - component.texture.get_size()
		add_theme_constant_override("margin_right", margin.x*SCALE)
		add_theme_constant_override("margin_bottom", margin.y*SCALE)
		$TextureRect.custom_minimum_size = component.texture.get_size()*SCALE
		
		$influence/CollisionShape2D.shape = RectangleShape2D.new()
		$influence/CollisionShape2D.shape.size = component.texture.get_size()*SCALE
		
		$influence.position = component.texture.get_size()*SCALE*0.5
		#$left.position = Vector2(0, component.texture.get_size().y*SCALE*0.5)
		#$top.position = Vector2(component.texture.get_size().x*SCALE*0.5, 0)
		#$right.position = Vector2(component.texture.get_size().x*SCALE, component.texture.get_size().y*SCALE*0.5)
		#$bottom.position = Vector2(component.texture.get_size().x*SCALE*0.5, component.texture.get_size().y*SCALE)
	
	
func rotate_component(a = null):
	if component.texture:
		rotate = str((int(rotate)+90)%360) if not a else str(int(a))
		var image = component.texture.get_image()
		for i in range(0, int(int(rotate)/90.0)):
			image.rotate_90(CLOCKWISE)
		if not in_drag_space:
			$TextureRect.texture = ImageTexture.create_from_image(image)
			
	oversize()
		
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
				print("released")
				if pre_drag_space:
					rotate_component()
				in_drag_space = false
				pre_drag_space = false
				_ready()
		else:
			if pre_drag_space and abs(mouse_when_pressed.x - get_local_mouse_position().x) + abs(mouse_when_pressed.y - get_local_mouse_position().y) > 3:
				in_drag_space = true
				pre_drag_space = false
				# instantiate new
				_ready()
			
			#get_node("/root/main").player.drag_inventory_item(self, Vector2(0,0)) #custom_minimum_size*0.5


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
