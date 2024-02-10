extends CharacterBody2D

@export var myname = "player"
@export var health = 100.0

const is_player = true

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const SCALE = 3.0

var counter = 0
var last_health
var mouse_target = null

var activatables = []
var combinables = []
var dragged_item = null
var dragged_item_mutex = false

@export var inventory : Inv
@export var quickinventory : Inv

func _ready():
	last_health = health
	
	get_node("/root/main/HUD/FullInventory").visible = false
	for e in [inventory, quickinventory]:
		for i in range(0, e.items.size()):
			if not e.items[i]:
				e.items[i] = InvSlot.new()
	$PlayerReach/Sprite2D.visible = false
	pass
	
func drag_inventory_item(uiitem, offset):
	# stupid bug, have to clone item for each canvas layer bc collision will not move with hud
	var myitem = {}
	for l in ["UI", "world"]:
		myitem[l] = preload("res://items/item_world.tscn").instantiate()
		myitem[l].itemslot = uiitem.itemslot.duplicate()
		myitem[l].name = "dragged_item_"+l
		myitem[l].position = DisplayServer.mouse_get_position() #-offset*0.33333
		if l == "UI":
			myitem[l].scale = Vector2(SCALE, SCALE)
			get_node("/root/main/HUD").add_child(myitem[l])
			myitem[l].position = get_node("/root/main/HUD/MousePosition").get_local_mouse_position()-offset/SCALE
		else:
			myitem[l].visible = false
			myitem[l].scale = Vector2(1, 1)
			get_node("/root/main/World").add_child(myitem[l])
			myitem[l].position = get_node("/root/main/World").get_local_mouse_position()-offset
			
		myitem[l].set_in_drag_space(l)
		myitem[l].z_index = 3000
	dragged_item = {"obj": myitem["world"], "obj-uiclone": myitem["UI"], "ui": uiitem, "offset": offset/SCALE}
	dragged_item_mutex = true
	

func arr_remove_dirty(arr):
	var out = [];
	for i in range(arr.size()):
		if is_instance_valid(arr[i][0]) and is_instance_valid(arr[i][1]):
			out.append(arr[i])
		else:
			print("Stale dirty resolvable: "+str(arr[i][0])+" - "+str(arr[i][1]))
	return out

@export var with  : InvItem
@export var yields : InvItem = InvItem.new()
@export var amount : int = 1
@export var eats_source : bool = true
@export var eats_target : bool = true

func use_item_on_item(aidx, bidx):
	for combo in inventory.items[aidx].item.combos:
		if inventory.items[bidx].item == combo.with:
				p("Used "+inventory.items[aidx].item.name+" on "+inventory.items[bidx].item.name+".")
				if combo.yields and combo.yields != preload("res://items/blank.tres"):
					p("Crafted new item: "+combo.yields.name+".")
					add_inventory_item(InvSlot.new(combo.yields, combo.amount))
				inventory.items[aidx].count -= 1 if combo.eats_source else 0
				inventory.items[bidx].count -= 1 if combo.eats_target else 0
				for i in [aidx, bidx]:
					if inventory.items[i].count <= 0:
						inventory.items[i] = InvSlot.new()
				return true
	p("Can't use "+inventory.items[aidx].item.name+" on "+inventory.items[bidx].item.name+".")
	return false

# TODO combinables should not only work via mouse drag
func resolve_combinables(mode):
	combinables = arr_remove_dirty(combinables)
	combinables.sort_custom(func(a, b): return (a[0] if a[0].z_index < a[1].z_index else a[1]).z_index > (b[0] if b[0].z_index < b[1].z_index else b[1]).z_index)	
	print("Trying to combine: "+str(combinables))
	for arr in combinables.duplicate():
		var world_item = arr.filter(func(e): return e is StaticBody2D and "itemslot" in e)
		world_item = world_item[0] if world_item.size() > 0 else null
		var other_item = arr.filter(func(e): return not (e is StaticBody2D and "itemslot" in e))
		other_item = other_item[0] if other_item.size() > 0 else null
		if mode == "dragging" and world_item and other_item:
			combinables.erase(arr)
			# dragged onto enemy / player (or ???)
			if other_item.name == "hitbox":
				if other_item.get_parent() == self:
					p("Consuming item not impremented yet.")
					return false
				if "health" in other_item.get_parent() and world_item.itemslot.item.damage > 0:
					other_item.get_parent().health -= world_item.itemslot.item.damage
					p("Did "+str(world_item.itemslot.item.damage)+" damage to "+(other_item.get_parent().myname if "myname" in other_item.get_parent() else str(other_item))+" with "+world_item.itemslot.item.name+"!")
					return false
			# item is targeting inventory slot
			elif other_item.name.substr(0,13) == "InventoryItem":
				print("Putting item into UI")
				var inv = quickinventory if other_item.is_quick else inventory
				if other_item.idx < inv.items.size():
					if dragged_item and dragged_item["obj-uiclone"] == world_item:
						# from full or quick into quick -> always overwrite
						if other_item.is_quick:
							# delete if it is already there
							if inv.has(dragged_item["ui"].itemslot.item):
								inv.items[inv.find(dragged_item["ui"].itemslot.item)] = InvSlot.new()
							inv.items[other_item.idx] = world_item.itemslot.duplicate()
						# from full into full
						elif not dragged_item["ui"].is_quick and not other_item.is_quick:
							# check if it is an empty slot
							if inv.items[other_item.idx].item == preload("res://items/blank.tres"):
								inv.items[dragged_item["ui"].idx] = InvSlot.new()
								inv.items[other_item.idx] = world_item.itemslot.duplicate()
							# slot is not empty
							else:
								use_item_on_item(dragged_item["ui"].idx, other_item.idx)
						# from quick into full
						else:
							p('Can\'t put from quickinventory into full inventory.')
				return false
			# item seems to be targeting world
			else:
					# check if item is within reach
					if world_item in $PlayerReach.get_overlapping_bodies():
						$PlayerReach/RayCast2D.target_position = (world_item.global_position - $PlayerReach/RayCast2D.global_position)/SCALE
						$PlayerReach/RayCast2D.force_raycast_update()
						if $PlayerReach/RayCast2D.get_collider():
							world_item.global_position = $PlayerReach/RayCast2D.get_collision_point()
						if other_item is TileMap:
							p(world_item.itemslot.item.name+" put on floor.")
							return true
						elif other_item is StaticBody2D:
							var other_item_name = other_item.myname if "myname" in other_item else str(other_item)
							if other_item.has_method("combine"):
								# success, consumed
								var outcome = other_item.combine(world_item.itemslot)
								if outcome.size() <= 2 or outcome[2] == true:
									match outcome.slice(0,2):
										[true, false]:
											p("Used "+world_item.itemslot.item.name+" on "+other_item_name+".")
										[true, true]:
											p("Spend "+world_item.itemslot.item.name+" on "+other_item_name+".")
										[false, false]:
											p(""+world_item.itemslot.item.name+" doesn't work on "+other_item_name+".")
										[false, true]:
											p("Wasted "+world_item.itemslot.item.name+" on "+other_item_name+".")
								return outcome[1]
							else:
								p("Can't use "+world_item.itemslot.item.name+" on "+other_item_name+".")
								return false
						p("can't combine??"+str(arr))
					else:
						p("Out of reach.")
						return false
	return false

func drag_apply_inventory_item():
	var success = resolve_combinables("dragging")
	if success:
		# for the time we only drop one piece
		var idx = inventory.find(dragged_item["ui"].itemslot.item)
		inventory.items[idx].count -= 1 if inventory.items[idx].count - 1 >= 0 else 0
		if inventory.items[idx].count == 0:
			inventory.items[idx] = InvSlot.new()
		dragged_item["obj"].itemslot.count = 1
		
		print("Item count now: "+str(inventory.items[idx].count))
		
	dragged_item["obj"].name = dragged_item["obj"].itemslot.item.short_name
	dragged_item["obj"].set_in_drag_space("false")
	dragged_item["obj"].visible = true
	dragged_item["obj"].z_index = 0
	
	combinables = combinables.filter(func(e): return not e.has(dragged_item["obj"]))
	dragged_item["ui"].in_drag_space = false
	
	if not success:
		get_node("/root/main/World").remove_child(dragged_item["obj"])
		dragged_item["obj"].queue_free()
		dragged_item["obj"] = null
	#else:
		#dragged_item["obj"].scale = Vector2(1,1)
		#dragged_item["obj"].call_deferred("reparent",get_node("/root/main/World"))

	$PlayerReach/Sprite2D.visible = false
	get_node("/root/main/HUD").remove_child(dragged_item["obj-uiclone"])
	dragged_item["obj-uiclone"].queue_free()
	dragged_item["obj-uiclone"] = null
		
	dragged_item = null

# this is for keyboard action currently
func add_inventory_item(itemslot):
	if inventory.has(itemslot.item): # TODO and if its not modded
		inventory.items[inventory.find(itemslot.item)].count += itemslot.count
		return true
	else:
		for i in range(0, inventory.items.size()):
			if inventory.items[i].item == preload("res://items/blank.tres"):
				inventory.items[i] = itemslot.duplicate()
				return true
	return false

func _input(event):
	if dragged_item and dragged_item_mutex:
				$PlayerReach/Sprite2D.visible = true
				dragged_item["obj"].position = get_node("/root/main/World").get_local_mouse_position()-dragged_item["offset"]
				dragged_item["obj-uiclone"].position = get_node("/root/main/HUD/MousePosition").get_local_mouse_position()-dragged_item["offset"]/SCALE
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pass
		elif not event.pressed:
				if dragged_item:
					dragged_item_mutex = false
					drag_apply_inventory_item()
#	if event.is_action_pressed("mouse_button_1"):
#		mouse_target = get_global_mouse_position()
	
	if Input.is_action_just_pressed("action_1"):
		for obj in activatables:
			obj.activate(self)
	if Input.is_action_just_pressed("pause"):
		pass#get_tree().paused = true
		
	if Input.is_action_just_pressed("action_inventory"):
		get_node("/root/main/HUD/FullInventory").visible = not get_node("/root/main/HUD/FullInventory").visible

func _physics_process(delta):
	counter = (counter+1)%9999999999

	# Handle jump.
	#if Input.is_action_just_pressed("action_1") and is_on_floor():
	#	velocity.y = JUMP_VELOCITY

	# keyboard
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED
	if direction.x + direction.y > 0.1:
		mouse_target = null

	# mouse
	if mouse_target:
		velocity += (SCALE*position).direction_to(mouse_target) * SPEED
		if (SCALE*position).distance_to(mouse_target) < 10:
			mouse_target = null

	velocity = velocity.normalized()*SPEED

	if velocity.x < 0:
		$Sprite.flip_h = true
	elif velocity.x > 0:
		$Sprite.flip_h = false

	if abs(velocity.x) + abs(velocity.y) < 0.1:
		$Sprite.play("default")
	else:
		$Sprite.play("run")
		
	# update stuff less frequently
	if counter%10 == 0:
		var mr = min(health,100)/100.0
		$Sprite.set_modulate(Color(1,mr,mr,1))
	if counter%10 == 0:
		if health < last_health:
			var mr = min(last_health - health,20)/20.0
			mr *= 100.0/(health if health > 0 else 1) if health-50 < 0 else 1
			mr = 1 if mr > 1 else mr
			$HurtBox/HurtShader.material.set_shader_parameter("alpha", mr)
			last_health -= 1
		else:
			$HurtBox/HurtShader.material.set_shader_parameter("alpha", 0.0)

	move_and_slide()
	
func p(s):
	get_node("/root/main").p(s)
