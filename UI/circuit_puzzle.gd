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

var circuit = []

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
	
	update_components_oversized_relay()
	
	circuit = []
	for inp in myinputs:
		var e_list = {}
		get_recursive_connections(inp, e_list, inp)
		for e in $GridContainer.get_children():
			e.set_modulate(Color(1,1,1,1))
		for e in e_list:
			e.set_modulate(Color(0.9,0.45,0.45,1))
		
	timer_update.start(0.2)

func get_recursive_connections(e, e_list, source):
	var cons = get_component_connections(e)
	if cons:
		e_list[e] = cons
		for num in cons:
			for node in cons[num]:
				if node != source and not node in e_list:
					get_recursive_connections(node, e_list, e)


# [1 = [node1, node2], 2 = [node3]]
func get_component_connections(e, back_test = false):
	if not e.component.texture:
		return {}
	var connections = {}
	var rotated_connections = e.get_rotated_connections()

	# get shift values for bigger oversized components
	var oversized = ceil(e.component.texture.get_size()/e.NORMAL_SIZE)
	if e.rotate in ["90", "270"]:
		oversized = Vector2(oversized.y, oversized.x)
		
	# loop over the connections ["left": [null, 1], "right": [2,3] ...]
	for s in rotated_connections:
		var ctn = 0
		for ss in rotated_connections[s]:
			var idx = e.idx
			var outside_bounds = false
			# kind of ugly, but this never needs to be changed ever again ... so fuck it
			match s:
				"left", "right":
					idx += grid_width * ctn + (int(oversized.x-1) if s == "right" else 0)
					if (idx+(0 if s=="left" else 1))%grid_width == 0:
						outside_bounds = true
				"top", "bottom":
					idx += ctn + (grid_width * int(oversized.y-1) if s == "bottom" else 0)
					if (s == "top" and idx < grid_width) or (s == "bottom" and idx >= (grid_width-1)*grid_height):
						outside_bounds = true
			if not outside_bounds and ss != null:
				var cons = $GridContainer.get_node("./CircuitComponent"+str(idx)).get_node(s).get_overlapping_areas()
				# check back if connection point connects to node from it's end
				if not back_test:
					for c in cons:
						var back_node = c.get_parent() if not c.get_parent().relay_to_node else c.get_parent().relay_to_node
						var back_cons = get_component_connections(back_node, true)
						var found = false
						for num in back_cons:
							for node in back_cons[num]:
								if node == e:
									found = true
						if not found: 
							cons.erase(c)
				# prepare return values: [1: [node, node], 2: [node]]
				if cons:
					if not connections.has(ss):
						connections[ss] = []
					for c in cons:
						var back_node = c.get_parent() if not c.get_parent().relay_to_node else c.get_parent().relay_to_node
						connections[ss] += [back_node]
			ctn += 1
	return connections
	
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
			grid_container.add_child(item)
			item.set_owner(get_tree().get_edited_scene_root())
		component_node_array.append(grid_container.get_node("./"+itemname))

	update_components_oversized_relay()

func update_components_oversized_relay():
	for i in range(0,component_node_array.size()):
		component_node_array[i].relay_to_node = null
	for i in range(0,component_node_array.size()):
		if component_node_array[i].component.texture:
			var oversized = ceil(component_node_array[i].component.texture.get_size()/component_node_array[i].NORMAL_SIZE)
			if component_node_array[i].rotate in ["90", "270"]:
				oversized = Vector2(oversized.y, oversized.x)
			for k in range(0, oversized.y):
				for j in range(0, oversized.x):
					if not k+j == 0:
						component_node_array[i+j+k*grid_width].relay_to_node = component_node_array[i]
		


## not needed!
#func disconnect_all_signals(node):
#		for cur_signal in node.get_signal_list():
#			for cur_conn in node.get_signal_connection_list(cur_signal.name):
#				if cur_conn.callable.get_object() == node and node.is_connected(cur_conn.signal.get_name(), cur_conn.callable):
#					print("is connected: "+str(cur_conn.signal.get_name())+" in "+str(cur_signal.name))
#					disconnect(cur_conn.signal.get_name(), cur_conn.callable)
