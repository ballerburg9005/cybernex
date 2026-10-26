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
var last_hovered_world: CollisionObject2D

var mouse_over_ui = false
var puzzle_active: bool = false
var active_circuit: CircuitWorkbench
var current_drawer_page: int = 0
var desk_inspection: Control
const BACKPACK_DRAWER_WIDTH := 522.0
const BODY_DRAWER_WIDTH := 522.0
var companion_drawer: CompanionDrawer
const QUICKBAR_WIDTH := 506.0
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
    $HUD/FullInventory/VBoxContainer/DrawerNav/NavRow/Previous.pressed.connect(func() -> void:
        cycle_drawer(-1)
    )
    $HUD/FullInventory/VBoxContainer/DrawerNav/NavRow/Next.pressed.connect(func() -> void:
        cycle_drawer(1)
    )
    $HUD/FullInventory/VBoxContainer/DrawerNav/NavRow/Close.pressed.connect(toggle_inventory)
    companion_drawer = preload("res://UI/CompanionDrawer.tscn").instantiate()
    $HUD.add_child(companion_drawer)
    companion_drawer.z_index = 1000
    companion_drawer.bind_inventory(player.inventory)
    companion_drawer.backpack_view.feedback.connect(p)
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
    $HUD/QuickInventory.visible = true
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
    dark.set_corner_radius_all(0)
    # Journal sides are twice as spacious as top/bottom.
    dark.content_margin_left = 6.0
    dark.content_margin_right = 18.0
    dark.content_margin_top = 9.0
    dark.content_margin_bottom = 9.0
    paper.add_theme_stylebox_override("panel", dark)
    var hotbar_back: StyleBoxFlat = dark.duplicate()
    hotbar_back.bg_color = Color("#111d2f")
    hotbar_back.set_corner_radius_all(19)
    hotbar_back.border_color = Color("#2b4358")
    hotbar_back.content_margin_left = 4
    hotbar_back.content_margin_right = 4
    hotbar_back.content_margin_top = 3
    hotbar_back.content_margin_bottom = 3
    $HUD/QuickInventory.add_theme_stylebox_override("panel", hotbar_back)
    $HUD/QuickInventory/InventoryItems.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    var enclosing: StyleBoxFlat = dark.duplicate()
    enclosing.content_margin_left = 5.0
    enclosing.content_margin_right = 5.0
    enclosing.content_margin_top = 5.0
    enclosing.content_margin_bottom = 5.0
    $HUD/FullInventory.add_theme_stylebox_override("panel", enclosing)
    # Navigation and contents share this ONE outer panel, not disconnected
    # dark cards floating over the game world.
    $HUD/FullInventory/VBoxContainer/DrawerNav.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    var page_back: StyleBoxFlat = dark.duplicate()
    page_back.content_margin_left = 14.0
    page_back.content_margin_right = 14.0
    page_back.content_margin_top = 9.0
    page_back.content_margin_bottom = 9.0
    $HUD/FullInventory/VBoxContainer/PdaPage.add_theme_stylebox_override("normal", page_back)
    $HUD/FullInventory/VBoxContainer/DrawerNav/NavRow/Section.add_theme_font_size_override("font_size", 28)
    $HUD/FullInventory/VBoxContainer/DrawerNav/NavRow/Section.add_theme_color_override("font_color", Color("#e7ece7"))
    $HUD/TextBox/S2.visible = false
    $HUD/TextBox/HBoxContainer/S3.visible = false
    var feed: RichTextLabel = hud_textbox
    feed.add_theme_font_size_override("normal_font_size", 17)
    feed.add_theme_font_size_override("bold_font_size", 17)
    feed.add_theme_color_override("default_color", Color("#e7ece7"))
    $HUD/TextBox/HBoxContainer/MarginContainer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    $HUD/TextBox/HBoxContainer.custom_minimum_size.y = 0.0
    $HUD/TextBox/HBoxContainer/MarginContainer.add_theme_constant_override("margin_right", 8)
    $HUD/TextBox/HBoxContainer/MarginContainer.add_theme_constant_override("margin_bottom", 6)
    $HUD/TextBox/HBoxContainer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    feed.fit_content = false
    feed.scroll_following = true
    feed.scroll_active = true
    feed.mouse_filter = Control.MOUSE_FILTER_STOP
    feed.add_theme_font_size_override("normal_font_size", 17)
    feed.add_theme_font_size_override("bold_font_size", 17)

func _layout_hud() -> void:
    if not is_inside_tree():
        return
    var viewport: Vector2 = get_viewport_rect().size
    var body_page: bool = current_drawer_page == 1
    var drawer_width: float = BODY_DRAWER_WIDTH if body_page else BACKPACK_DRAWER_WIDTH
    drawer_width = minf(drawer_width, viewport.x - 16.0)
    var drawer: Control = $HUD/FullInventory
    drawer.set_anchors_preset(Control.PRESET_TOP_LEFT)
    # Keep the entire primary drawer and its nav arrows fixed at left.
    drawer.offset_left = viewport.x - drawer_width - 8.0 if puzzle_active else 8.0
    drawer.offset_right = drawer.offset_left + drawer_width
    drawer.offset_top = 6.0
    drawer.offset_bottom = maxf(360.0, viewport.y - 95.0)
    if companion_drawer != null and is_instance_valid(companion_drawer):
        companion_drawer.visible = body_page and drawer.visible and not puzzle_active
        companion_drawer.set_anchors_preset(Control.PRESET_TOP_LEFT)
        companion_drawer.position = Vector2(drawer.offset_right - 1.0, drawer.offset_top)
        companion_drawer.size = Vector2(minf(BACKPACK_DRAWER_WIDTH, viewport.x - drawer.offset_right - 7.0),
            drawer.offset_bottom - drawer.offset_top)

    var quick: Control = $HUD/QuickInventory
    quick.set_anchors_preset(Control.PRESET_TOP_LEFT)
    quick.offset_left = (viewport.x - QUICKBAR_WIDTH) * 0.5
    quick.offset_right = quick.offset_left + QUICKBAR_WIDTH
    quick.offset_top = viewport.y - 73.0
    quick.offset_bottom = viewport.y - 4.0

    var journal: Control = $HUD/TextBox
    journal.set_anchors_preset(Control.PRESET_TOP_LEFT)
    journal.offset_left = 6.0 if puzzle_active else quick.offset_right + 8.0
    journal.offset_right = viewport.x - 6.0
    journal.offset_top = viewport.y - 125.0
    journal.offset_bottom = viewport.y - 4.0

    if active_circuit != null and is_instance_valid(active_circuit):
        active_circuit.set_anchors_preset(Control.PRESET_TOP_LEFT)
        active_circuit.position = Vector2(4, 4)
        active_circuit.size = Vector2(maxf(380.0, drawer.offset_left - 15.0),
            maxf(350.0, viewport.y - 73.0))

func _select_drawer_page(index: int) -> void:
    current_drawer_page = posmod(index, DRAWER_PAGES.size())
    var page: String = DRAWER_PAGES[current_drawer_page]
    $HUD/FullInventory/VBoxContainer/DrawerNav/NavRow/Section.text = page
    var row: Control = $HUD/FullInventory/VBoxContainer/HBoxContainer
    var backpack: Control = $HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/InventoryItems
    var body: Control = $HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/PanelContainer
    var pda: RichTextLabel = $HUD/FullInventory/VBoxContainer/PdaPage
    row.visible = current_drawer_page < 2
    backpack.visible = current_drawer_page == 0
    body.visible = current_drawer_page == 1
    var contents: HBoxContainer = $HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer
    if current_drawer_page == 1:
        contents.move_child(body, 0)
    else:
        contents.move_child(backpack, 0)
    pda.visible = current_drawer_page >= 2
    if current_drawer_page == 2:
        pda.text = "[b]STATION NOTES[/b]\n\nNo recovered entries."
    elif current_drawer_page == 3:
        pda.text = "[b]MAP[/b]\n\nMapping module has no cartographic data."
    elif current_drawer_page >= 4:
        pda.text = "[b]%s[/b]\n\nInstrument not installed." % page
    _layout_hud()

func cycle_drawer(step: int) -> void:
    _select_drawer_page(current_drawer_page + step)

func ui_captures_world_input() -> bool:
    # Only a real modal/precision circuit view takes over player movement.
    # Regular inventory/PDA are transparent to walking and Space interactions.
    return puzzle_active or (desk_inspection != null and is_instance_valid(desk_inspection))

func toggle_inventory() -> void:
    var drawer: Control = $HUD/FullInventory
    drawer.visible = not drawer.visible
    if drawer.visible:
        _select_drawer_page(0)
    _layout_hud()

func enter_circuit_mode(workbench: CircuitWorkbench) -> void:
    puzzle_active = true
    active_circuit = workbench
    $HUD/QuickInventory.visible = false
    $HUD/FullInventory.visible = true
    _select_drawer_page(0)
    _layout_hud()
    workbench.journal_event.connect(p)
    workbench.set_meter_unlocked(false)

func exit_circuit_mode() -> void:
    puzzle_active = false
    active_circuit = null
    $HUD/FullInventory.visible = false
    $HUD/QuickInventory.visible = true
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
    if node == player:
        return result # Self-label identifies a world actor, without intrusive diagnostics.
    if "itemslot" in node and node.itemslot != null and node.itemslot.occupied():
        result += "  %dx" % node.itemslot.count
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
    # Re-hit-test even with a stationary cursor. Moving sprites and the player
    # invalidate the old tooltip without requiring a mousemove event.
    var mouse_viewport: Vector2 = get_viewport().get_mouse_position()
    var moved: bool = mouse_viewport.distance_to(tooltip_last_mouse_position) >= 3.0
    tooltip_last_mouse_position = mouse_viewport
    if is_hud_drop_region(mouse_viewport):
        tooltip_display = 0
        last_hovered_world = null
        _clear_world_tooltip()
        return
    var collider: CollisionObject2D = $World/WorldHitTest.pick_viewport_point(mouse_viewport)
    var changed: bool = collider != last_hovered_world
    if changed or moved:
        last_hovered_world = collider
        tooltip_display = 0
        _clear_world_tooltip()
    if collider == null or not is_instance_valid(collider):
        return
    tooltip_display += 1
    if tooltip_display < TOOLTIP_WAIT or is_instance_valid(hud_tooltip):
        return
    var label: String = _hover_target_name(collider)
    if label.is_empty():
        return
    hud_tooltip = preload("res://tooltip.tscn").instantiate()
    hud_tooltip.name = "world_hover_tooltip"
    hud_tooltip.get_node("MarginContainer/Label").text = label
    hud.add_child(hud_tooltip)
    var desired: Vector2 = $HUD.get_final_transform().affine_inverse() * mouse_viewport + Vector2(14, 10)
    hud_tooltip.position = Vector2(
        clampf(desired.x, 2.0, maxf(2.0, get_viewport_rect().size.x - hud_tooltip.size.x - 4.0)),
        clampf(desired.y, 2.0, maxf(2.0, get_viewport_rect().size.y - hud_tooltip.size.y - 4.0)))
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

func is_hud_drop_region(screen_point: Vector2) -> bool:
    var ui_panels: Array[Control] = [
        $HUD/FullInventory, $HUD/QuickInventory, $HUD/TextBox
    ]
    if companion_drawer != null and is_instance_valid(companion_drawer):
        ui_panels.append(companion_drawer)
    if active_circuit != null and is_instance_valid(active_circuit):
        ui_panels.append(active_circuit)
    if desk_inspection != null and is_instance_valid(desk_inspection):
        ui_panels.append(desk_inspection)
    for control in ui_panels:
        if control.is_visible_in_tree() and control.get_global_rect().has_point(screen_point):
            return true
    return false

func _solid_drop_target(point: Vector2) -> bool:
    var shape := CircleShape2D.new()
    shape.radius = 5.0
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = shape
    query.transform = Transform2D(0.0, point)
    query.collision_mask = (1 << 19) | (1 << 21) | (1 << 22) | (1 << 23) | (1 << 6)
    query.collide_with_bodies = true
    return not world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _safe_drop_position(target: Vector2) -> Dictionary:
    # Never instantiate a physics item intersecting station tiles/walls.
    var clearance := CircleShape2D.new()
    clearance.radius = 9.0
    var shape_query := PhysicsShapeQueryParameters2D.new()
    shape_query.shape = clearance
    shape_query.collision_mask = (1 << 19) | (1 << 21) | (1 << 22) | (1 << 23) | (1 << 6)
    shape_query.collide_with_bodies = true
    var candidates: Array[Vector2] = [
        Vector2.ZERO, Vector2(24, 0), Vector2(-24, 0),
        Vector2(0, 24), Vector2(0, -24), Vector2(36, 36),
        Vector2(-36, 36), Vector2(36, -36), Vector2(-36, -36)
    ]
    for shift in candidates:
        var point: Vector2 = target + shift
        if point.distance_to(player.global_position) > player.service_reach():
            continue
        shape_query.transform = Transform2D(0.0, point)
        if world.get_world_2d().direct_space_state.intersect_shape(shape_query, 1).is_empty():
            return {"ok": true, "point": point}
    return {"ok": false}

## A GUI drag is only an item Resource payload. If released over valid world
## ground, create exactly one proper world body at the camera-converted point.
## No UI collision shapes or world-side drag clones are ever involved.
func _handle_world_drop(source: Inv, source_index: int, item: InvItem, viewport_position: Vector2, amount: int = 1) -> void:
    if item == null or player == null or world == null:
        return
    if source != player.inventory and source != player.quickinventory:
        return
    var drag_cell: InvSlot = source.slot_at(source_index)
    # Never look up an arbitrary item by type if a queued GUI refresh changed
    # the source slot during drag: that made pliers turn into other gear.
    if drag_cell == null or not Inv.matches(drag_cell.item, item) or amount < 1 \
        or not player.inventory.has(item, amount) \
        or (source == player.inventory and drag_cell.count < amount):
        return
    if puzzle_active or is_hud_drop_region(viewport_position):
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
    # A wall isn't a reachable ground drop. Reject the RELEASE position
    # itself before looking for safe floor nearby; shifting a rejected object
    # 24px sideways used to make pliers appear stuck ABOVE a wall.
    if collider != null or _solid_drop_target(world_point):
        p("%s cannot be used there." % item.name)
        return
    var safe: Dictionary = _safe_drop_position(world_point)
    if not bool(safe.get("ok", false)):
        p("There is nowhere for %s to land." % item.name)
        return
    if not player.inventory.remove_item(item, amount):
        return
    var dropped: Node2D = preload("res://items/item_world.tscn").instantiate()
    dropped.set("itemslot", InvSlot.new(item, amount))
    world.add_child(dropped)
    dropped.global_position = safe["point"]
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
    if companion_drawer != null:
        companion_drawer.bind_inventory(player.inventory)
    p("World slot loaded. Inventory, terminals, position and equipped systems restored.")
    return true
