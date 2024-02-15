@tool
extends PanelContainer

@export var grid_width = 6
@export var grid_height = 6

var component_scene = preload("res://UI/CircuitComponent.tscn")

var timer_update := Timer.new()

var is_world = false

var component_array = []
var component_node_array = []
@onready var grid_container = $GridContainer

func _ready():

	grid_container.columns = grid_width
	grid_container.size = Vector2(0,0)
	
#	if not Engine.is_editor_hint():
	call_deferred("_started")
	
	if not timer_update.is_inside_tree():
		timer_update.one_shot = true
		timer_update.timeout.connect(update_connections)
		add_child(timer_update)
	timer_update.start(0.2)

func update_connections():
	var myinputs  = component_node_array.filter(func(e): return e.component.is_input)
	var myoutputs = component_node_array.filter(func(e): return e.component.is_output)
	
	var circuit = []
	#while true:
		
		
	
func _started():
	for i in range(0, grid_width*grid_height):
		component_array.append(preload("res://UI/components/blank.tres"))


	for i in range(0, component_array.size()):
		var itemname = "CircuitComponent"+str(i)
		if not grid_container.has_node("./"+itemname):
			var item = component_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			item.name = itemname
			item.is_world = is_world
			item.component = component_array[i]
			component_node_array.append(item)
			grid_container.add_child(item)
			item.set_owner(get_tree().get_edited_scene_root())
		


## not needed!
#func disconnect_all_signals(node):
#		for cur_signal in node.get_signal_list():
#			for cur_conn in node.get_signal_connection_list(cur_signal.name):
#				if cur_conn.callable.get_object() == node and node.is_connected(cur_conn.signal.get_name(), cur_conn.callable):
#					print("is connected: "+str(cur_conn.signal.get_name())+" in "+str(cur_signal.name))
#					disconnect(cur_conn.signal.get_name(), cur_conn.callable)
