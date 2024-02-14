@tool
extends PanelContainer

@export var inv : Inv

var item_scene = preload("res://UI/InventoryItem.tscn")

var timer_update := Timer.new()

var is_world = false

@onready var grid_container = $GridContainer

func _update_items():

	for i in range(0, inv.items.size()):
		var node_name = "./InventoryItem"+str(i)
		if grid_container.has_node(node_name):
			var ui_inv_item = grid_container.get_node(node_name)
			if not ui_inv_item.itemslot == inv.items[i]:
				ui_inv_item.itemslot = inv.items[i]
				ui_inv_item.disabled = false
			if ui_inv_item.inv == preload("res://quickinventory.tres"):
				var playerinv = preload("res://playerinventory.tres")
				if not playerinv.has(ui_inv_item.itemslot.item):
					ui_inv_item.disabled = true
					ui_inv_item.itemslot = InvSlot.new()
				else:
					var playerinvslot = playerinv.items[playerinv.find(ui_inv_item.itemslot.item)]
					if playerinvslot != ui_inv_item.itemslot:
						ui_inv_item.itemslot = playerinvslot
			ui_inv_item._ready()


func _ready():
	if not inv:
		inv = Inv.new()

	grid_container.columns = int(ceil(sqrt(inv.items.size())))
	grid_container.size = Vector2(0,0)
	
#	if not Engine.is_editor_hint():
	call_deferred("_started")
	

func _started():
	if inv == preload("res://playerinventory.tres"):
		grid_container.columns = int(ceil(sqrt(inv.items.size())))
	elif inv == preload("res://quickinventory.tres"):
		grid_container.columns = 9
	
	if grid_container.columns < 3:
		grid_container.columns = 3

	if not inv == preload("res://quickinventory.tres"):
		for i in range(inv.items.size(), grid_container.columns * grid_container.columns):
			inv.items.append(InvSlot.new(preload("res://items/missing.tres")))

	if not Engine.is_editor_hint():
		timer_update.one_shot = false
		timer_update.timeout.connect(_update_items)
		add_child(timer_update)
		timer_update.start(0.2)


	for i in range(0, inv.items.size()):
		var item = item_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		item.name = "InventoryItem"+str(i)
		item.itemslot = inv.items[i]
		item.inv = inv
		item.is_world = is_world

		if grid_container.has_node("./"+item.name):
			var oldnode = grid_container.get_node("./"+item.name)
			grid_container.remove_child(oldnode)
			oldnode.queue_free()
			oldnode = null
			
		grid_container.add_child(item)
		item.set_owner(get_tree().get_edited_scene_root())
		


## not needed!
#func disconnect_all_signals(node):
#		for cur_signal in node.get_signal_list():
#			for cur_conn in node.get_signal_connection_list(cur_signal.name):
#				if cur_conn.callable.get_object() == node and node.is_connected(cur_conn.signal.get_name(), cur_conn.callable):
#					print("is connected: "+str(cur_conn.signal.get_name())+" in "+str(cur_signal.name))
#					disconnect(cur_conn.signal.get_name(), cur_conn.callable)
