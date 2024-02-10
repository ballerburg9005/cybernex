@tool
extends PanelContainer

@export var inv : InventoryUI

var item_scene = preload("res://UI/InventoryItem.tscn")

var timer_update := Timer.new()

func _update_items():
	if get_node("/root").has_node("main") and "player" in get_node("/root/main"):
		# TODO link inventory based on id, or something, instead of guessing by size
		var inventory
		if inv.cols*inv.rows > 20:
			inventory = get_node("/root/main").player.inventory
			for node in $GridContainer.get_children():
				node.is_quick = false
		else:
			inventory = get_node("/root/main").player.quickinventory
			for node in $GridContainer.get_children():
				node.is_quick = true
			
		for i in range(0, inv.cols*inv.rows):
			var node_name = "./InventoryItem"+str(i)
			if $GridContainer.has_node(node_name):
				var ui_inv_item = $GridContainer.get_node(node_name)
				if i < inventory.items.size() and inventory.items[i]:
					if not ui_inv_item.itemslot == inventory.items[i]:
						ui_inv_item.itemslot = inventory.items[i]
						ui_inv_item.disabled = false
					if ui_inv_item.is_quick:
						var playerinv = get_node("/root/main").player.inventory
						if not playerinv.has(ui_inv_item.itemslot.item):
							ui_inv_item.disabled = true
							ui_inv_item.itemslot = InvSlot.new()
						else:
							var playerinvslot = playerinv.items[playerinv.find(ui_inv_item.itemslot.item)]
							if playerinvslot != ui_inv_item.itemslot:
								ui_inv_item.itemslot = playerinvslot
							
				else:
					ui_inv_item.itemslot = InvSlot.new()
				ui_inv_item._ready()


func _ready():
	timer_update.one_shot = false
	timer_update.timeout.connect(_update_items)
	add_child(timer_update)
	timer_update.start(0.2)
		
	if not inv:
		inv = InventoryUI.new()
	$GridContainer.columns = inv.cols

	for i in range(0, inv.cols*inv.rows):
		var item = item_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		item.name = "InventoryItem"+str(i)
		item.itemslot = InvSlot.new()
		
		if $GridContainer.has_node("./"+item.name):
			var oldnode = $GridContainer.get_node("./"+item.name)
			$GridContainer.remove_child(oldnode)
			oldnode.queue_free()
			oldnode = null
			
		$GridContainer.add_child(item)
		item.set_owner(get_tree().get_edited_scene_root())
		


## not needed!
#func disconnect_all_signals(node):
#		for cur_signal in node.get_signal_list():
#			for cur_conn in node.get_signal_connection_list(cur_signal.name):
#				if cur_conn.callable.get_object() == node and node.is_connected(cur_conn.signal.get_name(), cur_conn.callable):
#					print("is connected: "+str(cur_conn.signal.get_name())+" in "+str(cur_signal.name))
#					disconnect(cur_conn.signal.get_name(), cur_conn.callable)
