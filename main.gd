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
var puzzle_active: bool = false
var active_circuit: CircuitWorkbench
var current_drawer_page: int = 0
const DRAWER_PAGES := ["BACKPACK", "BODY SYSTEMS", "NOTES", "MAP", "MULTIMETER", "OSCILLOSCOPE"]

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
    $HUD/FullInventory/VBoxContainer/DrawerNav/Previous.pressed.connect(func() -> void:
        cycle_drawer(-1)
    )
    $HUD/FullInventory/VBoxContainer/DrawerNav/Next.pressed.connect(func() -> void:
        cycle_drawer(1)
    )
    $HUD/FullInventory/VBoxContainer.move_child($HUD/FullInventory/VBoxContainer/DrawerNav, 0)
    get_viewport().size_changed.connect(_layout_hud)
    $HUD/FullInventory.visibility_changed.connect(_layout_hud)
    _setup_compact_hud()
    _layout_hud()
    _select_drawer_page(0)
    hud_textbox.text = "System initialized."


func _setup_compact_hud() -> void:
    # Strip the old fullscreen/spacer layout, not its authored scene nodes.
    $HUD/FullInventory/VBoxContainer/HBoxContainer/S.visible = false
    $HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/S2.visible = false
    $HUD/FullInventory/VBoxContainer/HBoxContainer/S3.visible = false
    $HUD/FullInventory/VBoxContainer/S.visible = false
    $HUD/QuickInventory/S.visible = false
    $HUD/FullInventory/VBoxContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    $HUD/FullInventory/VBoxContainer/HBoxContainer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var backpack: InventoryView = $HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/InventoryItems
    backpack.custom_minimum_size = Vector2(0, 0)
    backpack.size_flags_vertical = Control.SIZE_EXPAND_FILL
    $HUD/QuickInventory/InventoryItems.custom_minimum_size = Vector2(0, 0)
    var paper: PanelContainer = $HUD/TextBox/HBoxContainer/MarginContainer/PanelContainer
    var dark := StyleBoxFlat.new()
    dark.bg_color = Color(0.05, 0.075, 0.09, 0.95)
    dark.border_color = Color(0.31, 0.39, 0.4)
    dark.set_border_width_all(1)
    dark.set_corner_radius_all(7)
    paper.add_theme_stylebox_override("panel", dark)
    var feed: RichTextLabel = hud_textbox
    feed.add_theme_font_size_override("normal_font_size", 17)
    feed.add_theme_font_size_override("bold_font_size", 17)
    feed.add_theme_color_override("default_color", Color("#e7ece7"))
    $HUD/TextBox/HBoxContainer/MarginContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    $HUD/TextBox/HBoxContainer.custom_minimum_size.y = 122.0
    $HUD/TextBox/HBoxContainer.size_flags_vertical = Control.SIZE_SHRINK_END
    $HUD/TextBox/HBoxContainer/MarginContainer/PanelContainer/RichTextLabel.scroll_following = true

func _layout_hud() -> void:
    if not is_inside_tree():
        return
    var viewport: Vector2 = get_viewport_rect().size
    var drawer_width: float = clampf(viewport.x * 0.32, 366.0, 500.0)
    var drawer: Control = $HUD/FullInventory
    drawer.anchor_left = 0.0
    drawer.anchor_right = 0.0
    drawer.anchor_top = 0.0
    drawer.anchor_bottom = 0.0
    drawer.offset_left = viewport.x - drawer_width - 8.0 if puzzle_active else 8.0
    drawer.offset_right = viewport.x - 8.0 if puzzle_active else drawer_width + 8.0
    drawer.offset_top = 6.0
    drawer.offset_bottom = maxf(360.0, viewport.y - 140.0)
    var quick: Control = $HUD/QuickInventory
    quick.anchor_left = 0.0
    quick.anchor_right = 0.0
    quick.anchor_top = 0.0
    quick.anchor_bottom = 0.0
    quick.offset_left = 8.0
    quick.offset_right = minf(480.0, viewport.x * 0.47)
    quick.offset_top = viewport.y - 65.0
    quick.offset_bottom = viewport.y - 8.0
    if active_circuit != null and is_instance_valid(active_circuit):
        active_circuit.set_anchors_preset(Control.PRESET_TOP_LEFT)
        active_circuit.position = Vector2(6, 6)
        active_circuit.size = Vector2(maxf(390.0, viewport.x - drawer_width - 24.0),
            maxf(350.0, viewport.y - 148.0))

func _select_drawer_page(index: int) -> void:
    current_drawer_page = posmod(index, DRAWER_PAGES.size())
    var page: String = DRAWER_PAGES[current_drawer_page]
    $HUD/FullInventory/VBoxContainer/DrawerNav/Section.text = page
    var row: Control = $HUD/FullInventory/VBoxContainer/HBoxContainer
    var backpack: Control = $HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/InventoryItems
    var body: Control = $HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/PanelContainer
    var pda: RichTextLabel = $HUD/FullInventory/VBoxContainer/PdaPage
    row.visible = current_drawer_page < 2
    backpack.visible = current_drawer_page == 0
    body.visible = current_drawer_page == 1
    pda.visible = current_drawer_page >= 2
    if current_drawer_page == 2:
        pda.text = "[b]STATION NOTES[/b]\n\nNo recovered entries."
    elif current_drawer_page == 3:
        pda.text = "[b]MAP[/b]\n\nMapping module has no cartographic data."
    elif current_drawer_page >= 4:
        pda.text = "[b]%s[/b]\n\nInstrument not installed." % page

func cycle_drawer(step: int) -> void:
    _select_drawer_page(current_drawer_page + step)

func enter_circuit_mode(workbench: CircuitWorkbench) -> void:
    puzzle_active = true
    active_circuit = workbench
    $HUD/QuickInventory.visible = false
    $HUD/FullInventory.visible = true
    $HUD/TextBox/HBoxContainer/S3.visible = false
    _select_drawer_page(0)
    _layout_hud()
    workbench.journal_event.connect(p)
    workbench.set_meter_unlocked(false)

func exit_circuit_mode() -> void:
    puzzle_active = false
    active_circuit = null
    $HUD/FullInventory.visible = false
    $HUD/QuickInventory.visible = true
    $HUD/TextBox/HBoxContainer/S3.visible = true
    _layout_hud()

func find_myname_recursively(node, name):
    if node.has_meta("myname") and node.get_meta("myname") == name:
        return node
    for n in node.get_children():
            var result = find_myname_recursively(n, name)
            if result:
                return result
    return null

func p(s):
    if str(s).is_empty():
        return
    s = str(s)[0].to_upper() + str(s).substr(1)
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
    if source != player.inventory and source != player.quickinventory:
        return
    if not player.inventory.has(item):
        return
    # GUI drag ends do not reliably emit mouse_exited; use the actual release
    # point rather than a stale global mouse_over_ui flag.
    if $HUD/FullInventory.visible and $HUD/FullInventory.get_global_rect().has_point(viewport_position):
        return
    var picker: WorldHitTest = $World/WorldHitTest
    # WorldHitTest returns global world-canvas positions, never World-local
    # coordinates. Mixing those caused false "Out of reach" near wall wires.
    var world_point: Vector2 = picker.viewport_to_world(viewport_position)
    if world_point.distance_to(player.global_position) > player.service_reach():
        p("The object is beyond your reach.")
        return
    var collider: CollisionObject2D = picker.pick_viewport_point(viewport_position)
    if collider != null:
        var world_target: Node = collider
        if collider.get_parent() != null and collider.get_parent().has_method("combine"):
            world_target = collider.get_parent()
        if world_target.has_method("combine"):
            var result: Variant = world_target.combine(InvSlot.new(item, 1))
            if result is Array and result.size() > 0 and bool(result[0]):
                p("%s made contact with %s." % [item.name, str(world_target.get("myname"))])
                # The object's own combine procedure defines whether its
                # physical tool/material is consumed. Reusable cutters survive.
                if result.size() > 1 and bool(result[1]):
                    player.inventory.remove_item(item, 1)
                return
        var robot: Node = collider
        if not robot.is_in_group("enemies") and robot.get_parent() != null and robot.get_parent().is_in_group("enemies"):
            robot = robot.get_parent()
        if robot.is_in_group("enemies"):
            if item.type & InvItem.IS_TOOL:
                robot.health = maxf(0.0, float(robot.health) - 0.8)
                if robot.has_method("stun_for"):
                    robot.stun_for(0.25)
                p("You struck the chassis with %s. Little damage." % item.name)
            else:
                p("%s bounced off the machine." % item.name)
            return
    # No valid target: drop exactly one physical object on the floor.
    if not player.inventory.remove_item(item, 1):
        return
    var dropped: Node2D = preload("res://items/item_world.tscn").instantiate()
    dropped.set("itemslot", InvSlot.new(item, 1))
    world.add_child(dropped)
    dropped.global_position = world_point
    p("%s dropped. Remaining: %d." % [item.name, player.inventory.count(item)])

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
        p("Nothing happens.")

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
