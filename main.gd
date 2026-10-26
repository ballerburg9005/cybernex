extends Control


var world
var player
var hud
var hud_full_inventory
var hud_quick_inventory
var hud_textbox
var camera

var TOOLTIP_WAIT = 6 # * timer 0.2s
var tooltip_timer = Timer.new()
var tooltip_last_mouse_position = Vector2(-1,-1)
var tooltip_display = 0
var hud_tooltip

var mouse_over_ui = false

var start_music_volume_temp = 0.0
var background_music_volume_temp = 0.0
var background_music_trigger = true

func _ready():
    world = $World
    hud = $HUD
    player = $World/Player
    camera = $World/Player/Camera2D
    $World/WorldHitTest.reference_physics_body = player
    hud_full_inventory = find_myname_recursively($HUD, "hud_full_inventory")
    hud_quick_inventory = find_myname_recursively($HUD, "hud_quick_inventory")
    hud_textbox = find_myname_recursively($HUD, "hud_textbox")
    # Runtime inventory bindings share the player model rather than serialized UI copies.
    var full_index: InventoryView = $HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/InventoryItems
    var quick_index: InventoryView = $HUD/QuickInventory/InventoryItems
    full_index.configure(player.inventory, null, "backpack")
    quick_index.configure(player.quickinventory, player.inventory, "hotbar")
    var mannequin: EquipmentMannequin = $HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/PanelContainer/MarginContainer/Equipment
    mannequin.setup(player.inventory, player.equipment)
    mannequin.set_runtime(player.equipment_runtime)
    full_index.feedback.connect(p)
    quick_index.feedback.connect(p)
    mannequin.feedback.connect(p)
    full_index.use_requested.connect(_use_inventory_item)
    full_index.save_requested.connect(save_game)
    full_index.load_requested.connect(load_game)
    quick_index.use_requested.connect(_use_inventory_item)
    player.weapon_fired.connect(_on_weapon_fired)
    full_index.world_drop_requested.connect(_handle_world_drop)
    quick_index.world_drop_requested.connect(_handle_world_drop)

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


func _clear_world_tooltip() -> void:
    if is_instance_valid(hud_tooltip):
        hud_tooltip.queue_free()
    hud_tooltip = null

func _hover_target_name(collider: CollisionObject2D) -> String:
    var node: Node = collider
    if node == null:
        return ""
    if not ("myname" in node) and node.get_parent() != null and "myname" in node.get_parent():
        node = node.get_parent()
    if not ("myname" in node):
        return ""
    var result: String = str(node.get("myname"))
    if "itemslot" in node and node.itemslot != null and node.itemslot.occupied():
        result += "  ×%d" % node.itemslot.count
    if player.diagnostic_level() > 0:
        if "access_granted" in node and "disabled" in node:
            result += "\n[NEURAL SCAN]  PLC: %s  |  HW: %s" % [
                "AUTHORIZED" if node.access_granted else "SEALED",
                "FAULT" if node.disabled else "ACTIVE"
            ]
        elif "health" in node:
            result += "\n[NEURAL SCAN]  chassis integrity: %.0f" % node.health
    return result

func tooltip_timer_update() -> void:
    # HUD Controls own their native tooltips. The single world picker lives
    # in the camera-driven World canvas. No CanvasLayer physics query or HUD
    # Area2D is permitted here: that caused 4.3 pan/zoom hover offsets.
    var mouse_viewport: Vector2 = get_viewport().get_mouse_position()
    var moved: bool = mouse_viewport.distance_to(tooltip_last_mouse_position) >= 3.0
    tooltip_last_mouse_position = mouse_viewport
    if moved or mouse_over_ui or $HUD/FullInventory.visible:
        tooltip_display = 0
        _clear_world_tooltip()
        return
    tooltip_display += 1
    if tooltip_display < TOOLTIP_WAIT or is_instance_valid(hud_tooltip):
        return
    var collider: CollisionObject2D = $World/WorldHitTest.pick_viewport_point(mouse_viewport)
    var label: String = _hover_target_name(collider)
    if label.is_empty():
        return
    hud_tooltip = preload("res://tooltip.tscn").instantiate()
    hud_tooltip.name = "world_hover_tooltip"
    hud_tooltip.get_node("MarginContainer/Label").text = label
    hud.add_child(hud_tooltip)
    hud_tooltip.global_position = $HUD.get_final_transform().affine_inverse() * mouse_viewport + Vector2(14, 10)
    hud_tooltip.z_index = 2000

func _on_ui_mouse_entered():
    #print("mouse_over_ui")
    mouse_over_ui = true


func _on_ui_mouse_exited():
    #print("mouse_not_over_ui")
    mouse_over_ui = false


func get_all_the_children(node, type = null):
    var children = []
    for n in node.get_children():
            if type == null:
                children.append(n)
            elif n.is_class(type):
                children.append(n)
            children.append_array(get_all_the_children(n, type))
    return children


func _on_StartMusic_timeout():
    start_music_volume_temp = $StartMusic.volume_db
    background_music_volume_temp = $BackgroundMusic.volume_db
    background_music_trigger = true
    $StartMusic/timeout/fadeout.start()

func _process(delta):
    if not $StartMusic/timeout/fadeout.is_stopped():
        var fade_duration = $StartMusic/timeout/fadeout.wait_time
        var fade_timer = $StartMusic/timeout/fadeout.time_left
        if fade_timer > 0.01:
            $StartMusic.volume_db = start_music_volume_temp + 10.0*log(fade_timer / fade_duration)
            if fade_timer / fade_duration < 0.5:
                $BackgroundMusic.volume_db = background_music_volume_temp + 10.0*log(0.5 + fade_timer / fade_duration)
                if background_music_trigger:
                    background_music_trigger = false
                    $BackgroundMusic.play()
        else:
            $StartMusic.stop()
            $StartMusic.volume_db = start_music_volume_temp
            $BackgroundMusic.volume_db = background_music_volume_temp 

## A GUI drag is only an item Resource payload. If released over valid world
## ground, create exactly one proper world body at the camera-converted point.
## No UI collision shapes or world-side drag clones are ever involved.
func _handle_world_drop(source: Inv, source_index: int, item: InvItem, viewport_position: Vector2) -> void:
    if item == null or player == null or world == null:
        return
    if mouse_over_ui:
        return
    if source != player.inventory and source != player.quickinventory:
        return
    if not player.inventory.has(item):
        return
    var world_point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * viewport_position
    if world_point.distance_to(player.global_position) > player.service_reach():
        p("Out of reach. Walk nearer before dropping supplies.")
        return
    if not player.inventory.remove_item(item, 1):
        return
    var dropped: Node2D = preload("res://items/item_world.tscn").instantiate()
    dropped.set("itemslot", InvSlot.new(item, 1))
    world.add_child(dropped)
    dropped.global_position = world_point
    p("Put %s on the floor. Remaining: %d." % [item.name, player.inventory.count(item)])

func _use_inventory_item(item: InvItem) -> void:
    if item == null:
        return
    if item.energy_wh > 0.0:
        if player.recharge_from(item):
            p("Installed %s. Suit battery: %.1f/%.0f Wh." % [
                item.name, player.equipment_runtime.charge_wh,
                player.equipment_runtime.capacity_wh])
        else:
            p("Cell not installed: battery full or stock unavailable.")
    else:
        p("%s has no direct use. Combine it or fit it to an appropriate socket." % item.name)

func _on_weapon_fired(hit: Node, energy_spent_wh: float) -> void:
    if hit != null and hit.is_in_group("enemies"):
        p("Arc burst disrupted %s (%.2f Wh)." % [str(hit.get("myname")), energy_spent_wh])
    else:
        p("Arc burst discharged (%.2f Wh). No target disrupted." % energy_spent_wh)

func save_game() -> bool:
    var success: bool = WorldSave.write(self)
    p("Saved to local slot 1." if success else "Save failed: check writable user storage.")
    return success

func load_game() -> bool:
    var success: bool = WorldSave.read(self)
    if not success:
        p("No compatible saved world state found.")
        return false
    var full_index: InventoryView = $HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/InventoryItems
    var quick_index: InventoryView = $HUD/QuickInventory/InventoryItems
    var mannequin: EquipmentMannequin = $HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/PanelContainer/MarginContainer/Equipment
    full_index.configure(player.inventory, null, "backpack")
    quick_index.configure(player.quickinventory, player.inventory, "hotbar")
    mannequin.setup(player.inventory, player.equipment)
    mannequin.set_runtime(player.equipment_runtime)
    p("World slot loaded. Inventory, terminals, position and equipped systems restored.")
    return true
