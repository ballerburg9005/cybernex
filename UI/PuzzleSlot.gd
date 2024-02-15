@tool
extends TextureRect

@export var component : Component

@export_enum("0", "90", "180", "270") var rotate: String = "0"

var in_drag_space = false

var inv : Inv

var disabled = false

var myname 

var idx = 0

var is_world = false

var timer_update := Timer.new()


func _ready():
	idx = int(name.substr(13))
	if not component:
		component = preload("res://UI/components/missing.tres")
	if disabled or in_drag_space:
		texture = preload("res://UI/components/blank.tres").texture
	else:
		texture = component.texture
	
	if component not in [preload("res://UI/components/blank.tres")]:
		myname = component.name
	
	stretch_mode = TextureRect.STRETCH_SCALE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	custom_minimum_size = Vector2(48, 48)
	
	if texture:
		var image = texture.get_image()
		for i in range(0, int(int(rotate)/90.0)):
			image.rotate_90(CLOCKWISE)
		texture = ImageTexture.create_from_image(image)
   
	var mytext
	match component.short_name:
		"transistor":
			mytext = "pnp" if component.pnp else "npn"
		"wire":
			if component.is_input:
				mytext = str(component.value)+"V IN"
			elif component.is_output:
				mytext = "OUT"


	$PanelContainer.visible = true if not in_drag_space else false
	if mytext:
		$PanelContainer.visible = true
		$PanelContainer/MarginContainer/Label.text = str(mytext)
	else:
		$PanelContainer.visible = false
		
	if is_world:
		$influence.set_collision_mask_value(30, false)
		$influence.set_collision_mask_value(29, true)
		
	if Engine.is_editor_hint():
		if not timer_update.is_inside_tree():
			timer_update.one_shot = true
			timer_update.timeout.connect(_ready)
			add_child(timer_update)
		timer_update.start(0.5)

func _on_focus_entered():
	material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/outline.gdshader")
	material.set_shader_parameter("add_margins", false)


func _on_focus_exited():
	material.shader = null


func _on_gui_input(event):
	if not disabled:
		if event.is_action_pressed("mouse_button_1") and not in_drag_space:
			in_drag_space = true
			_ready()
			get_node("/root/main").player.drag_inventory_item(self, Vector2(0,0)) #custom_minimum_size*0.5


func _on_body_entered(body):
	if is_visible_in_tree():
		get_node("/root/main").player.combinables.append([self, body])

func _on_body_exited(body):
	get_node("/root/main").player.combinables.erase([self, body])
