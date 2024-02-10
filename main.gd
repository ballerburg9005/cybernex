extends Control


var world
var player
var hud
var hud_full_inventory
var hud_quick_inventory
var hud_textbox

var TOOLTIP_WAIT = 6 # * timer 0.2s
var tooltip_timer = Timer.new()
var tooltip_last_mouse_position = Vector2(-1,-1)
var tooltip_display = 0
var hud_tooltip

var mouse_over_ui = false

func _ready():
	world = $World
	hud = $HUD
	player = $World/Player
	hud_full_inventory = find_myname_recursively($HUD, "hud_full_inventory")
	hud_quick_inventory = find_myname_recursively($HUD, "hud_quick_inventory")
	hud_textbox = find_myname_recursively($HUD, "hud_textbox")

	tooltip_timer.one_shot = false
	tooltip_timer.timeout.connect(tooltip_timer_update)
	add_child(tooltip_timer)
	tooltip_timer.start(0.2)
	
	$HUD.visible = true

	hud_textbox.text = "Game started."

func find_myname_recursively(node, name):
	if node.has_meta("myname") and node.get_meta("myname") == name:
		return node
	for n in node.get_children():
			var result = find_myname_recursively(n, name)
			if result:
				return result
	return null

func p(s):
	s = s[0].to_upper() + s.substr(1,-1)
	var textbox = get_node("/root/main").hud_textbox
	textbox.text += "\n"+s


func tooltip_timer_update():
	var mouse_not_moved = (tooltip_last_mouse_position - get_global_mouse_position()).length() < 0.2 
	tooltip_last_mouse_position = get_global_mouse_position()
	if mouse_not_moved and tooltip_display < TOOLTIP_WAIT:
		tooltip_display += 1
		return true
	elif not mouse_not_moved:
		tooltip_display = 0
		if hud_tooltip and hud_tooltip in hud.get_children():
			hud.remove_child(hud_tooltip)
			hud_tooltip.queue_free()
			hud_tooltip = null
		return true
	
	var direct_space = get_viewport().find_world_2d().direct_space_state
	var intersections = {"World": [], "UI": []}
	for l in ["World", "UI"]:
		var query = PhysicsPointQueryParameters2D.new()
		query.collide_with_areas = true
		query.collide_with_bodies = true
		if l == "UI":
			query.canvas_instance_id = hud.get_instance_id()
			query.position = hud.get_node("MousePosition").get_global_mouse_position()
		else:
			query.canvas_instance_id = PhysicsServer2D.body_get_canvas_instance_id(player.get_rid())
			query.position = get_global_mouse_position()
		
		#if query.canvas_instance_id == 0:
			#query.position += $Camera2D.get_target_position()-Vector2(get_viewport().size)/2
		var inters = direct_space.intersect_point(query)
		if inters:
			inters.sort_custom(func(a, b): return a.collider.z_index > b.collider.z_index)
			intersections[l] += inters.filter(func(e): return e.collider.is_visible_in_tree())
	
	if mouse_over_ui:
		intersections["World"] = []
	for i in intersections["UI"] + intersections["World"]:
		var thename = "-1"
		if "myname" in i.collider:
			thename = i.collider.myname
		elif "myname" in i.collider.get_parent():
			thename = i.collider.get_parent().myname
		elif "itemslot" in i.collider and i.collider.itemslot and i.collider.itemslot.item:
			thename = i.collider.itemslot.item.name
		elif "itemslot" in i.collider.get_parent() and i.collider.get_parent().itemslot and i.collider.get_parent().itemslot.item:
			thename = i.collider.get_parent().itemslot.item.name
		if str(thename) != "-1" and not hud_tooltip:
			if thename and thename.length() > 0:
				hud_tooltip = preload("res://tooltip.tscn").instantiate()
				hud_tooltip.name = "tooltip"
				hud_tooltip.get_node("MarginContainer/Label").text = thename
				hud_tooltip.global_position = hud.get_node("MousePosition").get_global_mouse_position()+Vector2(16,0)
				hud.add_child(hud_tooltip)
				hud_tooltip.z_index = 2000
			return true


func _on_ui_mouse_entered():
	print("mouse_over_ui")
	mouse_over_ui = true
	pass # Replace with function body.


func _on_ui_mouse_exited():
	print("mouse_not_over_ui")
	mouse_over_ui = false
	pass # Replace with function body.
