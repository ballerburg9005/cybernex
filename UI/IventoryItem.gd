@tool
extends TextureRect

@export var itemslot : InvSlot

var in_drag_space = false

var inv : Inv

var disabled = false

var myname 

var idx = 0

var is_world = false

func _ready():
	idx = int(name.substr(13))
	if not itemslot:
		itemslot = InvSlot.new(preload("res://items/missing.tres"))
	if disabled or (in_drag_space and itemslot.count < 2) or itemslot.count < 1:
		texture = preload("res://items/blank.tres").texture
	else:
		texture = itemslot.item.texture
	
	if itemslot.item not in [preload("res://items/blank.tres")]:
		myname = itemslot.item.name
	
	stretch_mode = TextureRect.STRETCH_SCALE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	custom_minimum_size = Vector2(48, 48)
	
	$PanelContainer/MarginContainer/Label.text = str(itemslot.count - (1 if in_drag_space else 0))
	
	if itemslot.count > 1 and not (in_drag_space and itemslot.count < 2):
		$PanelContainer.visible = true
	else:
		$PanelContainer.visible = false
		
	if is_world:
		$influence.set_collision_mask_value(30, false)
		$influence.set_collision_mask_value(29, true)
		

func _on_focus_entered():
	material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/outline.gdshader")
	material.set_shader_parameter("add_margins", false)


func _on_focus_exited():
	material.shader = null


func _on_gui_input(event):
	if not disabled:
		if event.is_action_pressed("mouse_button_1") and not (itemslot.item.type & itemslot.item.IS_NOT) and not in_drag_space:
			in_drag_space = true
			_ready()
			get_node("/root/main").player.drag_inventory_item(self, Vector2(0,0)) #custom_minimum_size*0.5


func _on_body_entered(body):
	if is_visible_in_tree():
		get_node("/root/main").player.combinables.append([self, body])

func _on_body_exited(body):
	get_node("/root/main").player.combinables.erase([self, body])
