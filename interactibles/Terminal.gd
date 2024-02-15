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
var is_connected = false
var playing_first_time = true
var connections = []
var has_loot = false

var ui_menu

signal do_activate
signal do_deactivate
signal do_toggle


func _ready():
	if loot.count() < loot.items.size():
		has_loot = true
		for i in range(0,max(9, loot.items.size())):
			if i >= loot.items.size():
				loot.items += [InvSlot.new()]
	
	for signal_description in get_signal_list():
		var signal_name = str(signal_description["name"])
		for connection in get_signal_connection_list(signal_name):
			if connection['signal'].get_name() in ["do_activate", "do_deactivate", "do_toggle"]:
				is_connected = true
				connections += [connection['signal'].get_name()]
				
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
	
	var toggled = false
	if ui_menu:
		if not (caller == ui_menu and action in ["loot", "activate"]):
			toggled = true
		get_node("/root/main").remove_child(ui_menu)
		ui_menu.queue_free()
		ui_menu = null

	if toggled:
		return false

	if action == "default" and has_loot:
		if disabled or not is_connected:
			spawn_lootbox()
		elif not loot_after_solved or access_granted:
				print("spawn multichice")
				spawn_multiui_menu()
	elif action == "loot":
		spawn_lootbox()
	elif disabled:
		get_node("/root/main").p(myname+" is not functional.")
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
	if playing_first_time:
		playing_first_time = false
		instant = true
		
	if "do_activate" in connections:
		is_activated = true
		do_activate.emit(self, instant)
	else:
		play_toggle(instant)


func play_deactivate(instant = false):
	if playing_first_time:
		playing_first_time = false
		instant = true
		
	if "do_deactivate" in connections:
		is_activated = false
		do_deactivate.emit(self, instant)
	else:
		play_toggle(instant)


func play_toggle(instant = false):
	if playing_first_time:
		playing_first_time = false
		instant = true
		
	if "do_toggle" in connections:
		is_activated = not is_activated
		do_toggle.emit(self, instant, is_activated)


func _on_influence_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	if not disabled:
		if "activatables" in body:
			body.activatables.append(self)
		if $AnimatedSprite2D:
			$AnimatedSprite2D.play("on")


func _on_influence_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	if ui_menu:
		get_node("/root/main").remove_child(ui_menu)
		ui_menu.queue_free()
		ui_menu = null
	if "activatables" in body and body.activatables.has(self):
		body.activatables.erase(self)
	if $AnimatedSprite2D:
		$AnimatedSprite2D.play("off")
