extends StaticBody2D

@export var myname = "terminal"

var mytype = "terminal"


@export var access_granted = false
@export var disabled = false
@export var puzzle_type = "none"
@export_range(0, 20) var puzzle_difficulty = 0
@export var loot : Inv = Inv.new(9)
@export var loot_after_solved = true

var SCALE = 3

var animation_playing = []
var is_activated = false
var has_loot = false

var ui_menu

signal do_activate
signal do_deactivate


func _ready():
	if loot.count() < loot.items.size():
		has_loot = true
		for i in range(0,max(9, loot.items.size())):
			if i >= loot.items.size():
				loot.items += [InvSlot.new()]
		
	call_deferred("_started")


# reset animation based on access
func _started():
	if access_granted:
		play_activate(true)
	else:
		play_deactivate(true)
		
	if puzzle_type == "none":
		access_granted = true


# start puzzle
func activate(caller, action = "default"):
	if action in ["loot", "activate"]:
		caller.get_parent().remove_child(caller)
		caller.queue_free()
		ui_menu = null
	
	if ui_menu:
		return false

	if action == "default" and has_loot:
		if disabled:
			spawn_lootbox()
		elif not loot_after_solved or access_granted:
				print("spawn multichice")
				spawn_multiui_menu()
	elif action == "loot":
		spawn_lootbox()
	elif disabled:
		get_node("/root/main").p("Terminal is not functional.")
	elif animation_playing.size() == 0:
		if access_granted:
			if not is_activated:
				play_activate()
			else:
				play_deactivate()
		elif puzzle_type == "none":
			play_activate()
		else:
			get_node("/root/main").p("Terminal needs to be fixed!")

func spawn_lootbox():
	ui_menu = preload("res://UI/Inventory.tscn").instantiate()
	ui_menu.inv = loot
	get_node("/root/main").add_child(ui_menu)
	ui_menu.z_index = 2000
	ui_menu.global_position = global_position
	ui_menu.size = Vector2(0,0)
	ui_menu.is_world = true
	pass

func spawn_multiui_menu():
	ui_menu = preload("res://interactibles/multichoice_box.tscn").instantiate()
	get_node("/root/main").add_child(ui_menu)
	ui_menu.z_index = 2000
	#ui_menu.global_position = get_global_transform_with_canvas().origin 
	ui_menu.global_position = global_position
	#print(get_global_transform_with_canvas().origin)
	#ui_menu.global_position
	var buttons = get_node("/root/main").get_all_the_children(ui_menu, "Button")
	for i in range(2,buttons.size()):
		buttons[i].get_parent().remove_child(buttons[i])
		buttons[i].queue_free()
	ui_menu.size = Vector2(0,0)
	buttons[0].text = "activate"
	buttons[1].text = "loot"
	
	buttons[0].button_up.connect(Callable(activate).bind(ui_menu, "activate"))
	buttons[1].button_up.connect(Callable(activate).bind(ui_menu, "loot"))


func play_activate(instant = false):
	is_activated = true
	do_activate.emit(self, instant)


func play_deactivate(instant = false):
	is_activated = false
	do_deactivate.emit(self, instant)


func _on_influence_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	if not disabled:
		if "activatables" in body:
			body.activatables.append(self)
		if $AnimatedSprite2D:
			$AnimatedSprite2D.play("on")


func _on_influence_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	if ui_menu:
		remove_child(ui_menu)
		ui_menu.queue_free()
		ui_menu = null
	if "activatables" in body and body.activatables.has(self):
		body.activatables.erase(self)
	if $AnimatedSprite2D:
		$AnimatedSprite2D.play("off")
