extends SceneTree

var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error(reason)

func _run() -> void:
    var main_scene: PackedScene = load("res://main.tscn")
    check(main_scene != null, "Overworld should parse.")
    if main_scene == null:
        quit(1)
        return
    # SceneTree --script starts with a 64x64 headless root, not the real 720p
    # game window. Model the actual supported viewport before sizing HUD.
    root.size = Vector2i(1280, 720)
    var game: Control = main_scene.instantiate()
    root.add_child(game)
    var drawer: Control = game.get_node("HUD/FullInventory")
    drawer.visible = true
    game._layout_hud()
    await process_frame # Let Godot sort nested native Containers after root offsets.
    print("HUD 720: viewport=", game.get_viewport_rect().size, " drawer=", drawer.get_global_rect())
    check(drawer.size.x >= 505.0 and drawer.size.x <= 555.0,
        "Original 3x art requires 10 complete 48-pixel cells in the drawer without clipping.")
    check(drawer.position.x <= 12.0, "Exploration inventory drawer must stay left of centered player.")
    var backpack_panel: InventoryView = game.get_node("HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/InventoryItems")
    check(backpack_panel.grid_container.columns == 10, "Player inventory must be ten cells wide.")
    check(backpack_panel.grid_container.get_child_count() <= maxi(10, ceili(float(game.player.inventory.size()) / 10.0) * 10),
        "Inventory must not manufacture offscreen filler rows based on its own expanding height.")
    check(backpack_panel.grid_container.get_global_rect().end.x <= drawer.get_global_rect().end.x + 1.0,
        "Inventory grid must fit horizontally inside the drawer.")
    var first_cell: InventoryCell = backpack_panel.grid_container.get_child(0)
    check(first_cell.custom_minimum_size == Vector2(48, 48)
        and first_cell.number.get_theme_font_size("font_size") >= 18,
        "Every authored 16px glyph stays 3x/48px and stack digits now have readable 18px size.")
    check(first_cell.number.text == "1x" and not first_cell.tooltip_text.contains("COMBINE WITH"),
        "Physical stacks need small 1x notation and item-identifying, not instructional, tooltips.")
    check(backpack_panel.grid_container.get_child_count() % 10 == 0, "Last inventory row must have visible empty cells.")
    var nav: Control = game.get_node("HUD/FullInventory/VBoxContainer/DrawerNav")
    check(nav is PanelContainer and nav.has_theme_stylebox_override("panel"), "All navigation labels must be backed as one panel.")
    check(game.get_node("HUD/FullInventory/VBoxContainer/PdaPage").has_theme_stylebox_override("normal"), "PDA text must render against an opaque-enough UI panel.")
    game._select_drawer_page(4)
    game.toggle_inventory()
    check(not drawer.visible, "Tab on any drawer page must close inventory, never switch page.")
    game.toggle_inventory()
    check(drawer.visible and game.current_drawer_page == 0,
        "Reopening inventory must start on backpack after Tab closed any page.")
    var quick: Control = game.get_node("HUD/QuickInventory")
    var log: Control = game.get_node("HUD/TextBox")
    check(drawer.mouse_filter == Control.MOUSE_FILTER_STOP
        and quick.mouse_filter == Control.MOUSE_FILTER_STOP
        and log.mouse_filter == Control.MOUSE_FILTER_STOP,
        "Opaque HUD background, navigation, shortcut bar and journal must consume GUI mouse events.")
    var journal: RichTextLabel = game.hud_textbox
    print("JOURNAL 720: label=", journal.get_global_rect(), " text=", journal.text, " richbox=", journal.get_parent().get_global_rect(), " hbox=", log.get_node("HBoxContainer").get_global_rect())
    check(journal.get_global_rect().position.y >= 0.0
        and journal.get_global_rect().size.y >= 65.0
        and journal.get_global_rect().end.y <= 720.0
        and journal.text.contains("System initialized."),
        "Accessible lower-right journal must show actual text inside a tall, onscreen layout.")
    check(journal.scroll_active and journal.mouse_filter == Control.MOUSE_FILTER_STOP,
        "Mouse wheel must scroll the event journal without triggering world interactions.")
    check(game.get_node("World/Player").quickinventory.size() == 10
        and game.get_node("HUD/QuickInventory/InventoryItems").grid_container.get_child_count() == 10,
        "Centered quickbar must have exactly ten reference-only shortcuts.")
    check(quick.visible and absf(quick.get_global_rect().get_center().x - 640.0) < 5.0
        and quick.get_global_rect().end.x + 2.0 <= log.get_global_rect().position.x,
        "Ten physical quickbar shortcuts must be centered at the bottom and not overlap the journal.")
    var quick_grid: Control = game.get_node("HUD/QuickInventory/InventoryItems/Layout/Scroll/GridContainer")
    var quick_bounds: Rect2 = quick_grid.get_global_rect()
    print("QUICKBAR 720: root=", quick.get_global_rect(), " cells=", quick_bounds, " journal=", log.get_global_rect())
    check(quick_bounds.size.x > 460.0 and quick_bounds.position.y >= 0.0
        and quick_bounds.end.y <= 720.0 and quick.get_global_rect().end.y <= 720.0,
        "All ten quickbar item shortcuts must be physically visible in bottom-center HUD.")
    var journal_scroll: VScrollBar = journal.get_v_scroll_bar()
    check(journal_scroll != null and journal_scroll.get_global_rect().end.y <= 720.0,
        "Event journal vertical scrollbar must stay above the window bottom edge.")
    for i in range(30):
        game.p("Equipment and station event %d" % i)
    await process_frame
    check(journal_scroll.visible and journal_scroll.get_global_rect().end.y <= 720.0
        and journal_scroll.get_global_rect().end.x <= 1280.0,
        "A populated accessible event log must show its wheel-scrolling bar FULLY on screen.")
    check(game.get_node("HUD/FullInventory/VBoxContainer/DrawerNav/NavRow/Section").get_theme_font_size("font_size") >= 28,
        "Backpack and Body headings must have legible doubled font size.")
    check(game.get_node("HUD/FullInventory/VBoxContainer/DrawerNav/NavRow/Close") is Button,
        "Backpack navigation CLOSE button must sit next to the right arrow.")
    check(not game.ui_captures_world_input(), "Normal inventory must allow walking and Space interactions.")
    Input.action_press("move_right")
    var actor: CharacterBody2D = game.get_node("World/Player")
    actor._physics_process(0.016)
    check(actor.velocity.x > 0, "Holding move-right must still move player with backpack open.")
    Input.action_release("move_right")
    game.toggle_inventory()
    check(not game.ui_captures_world_input(), "Closing UI should retain world controls.")
    root.size = Vector2i(1920, 1080)
    drawer.visible = true
    game._layout_hud()
    check(drawer.get_global_rect().end.x < 1920.0 and drawer.get_global_rect().position.x <= 12.0,
        "1080p exploration drawer must stay fully onscreen at fixed left margin.")
    game._select_drawer_page(1)
    await process_frame # Godot Container defers child sorting after move_child.
    var visible_backpack: Control = game.companion_drawer.backpack_view
    check(visible_backpack.visible and game.companion_drawer.visible
        and game.companion_drawer.backpack_view.inv == game.player.inventory,
        "Body systems must keep a distinct switchable companion with the ACTUAL backpack.")
    var mannequin: Control = game.get_node("HUD/FullInventory/VBoxContainer/HBoxContainer/HBoxContainer/PanelContainer/MarginContainer/Equipment")
    check(mannequin.get_global_rect().end.x <= visible_backpack.get_global_rect().position.x + 3.0,
        "Fixed-width mannequin must remain LEFT of the independent inventory/instrument pane.")
    check(game.companion_drawer.get_global_rect().end.x <= 1920.0,
        "Auxiliary instrument/backpack pane must fit on screen.")
    check(drawer.position.x <= 12.0 and drawer.size.x < 570,
        "Body selection must not shift or widen the primary page/navigation box.")
    game.companion_drawer.select_page(1)
    check(not visible_backpack.visible and game.companion_drawer.get_node("Layout/Info").visible,
        "Player can page to multimeter without leaving Body Systems.")
    game.companion_drawer.select_page(0)
    game._select_drawer_page(0)
    drawer.visible = false
    root.size = Vector2i(1280, 720)
    game._layout_hud()
    drawer.visible = false
    var item: InvItem = load("res://items/wires.tres")
    var player = game.get_node("World/Player")
    var world: Node2D = game.get_node("World")
    var picker: WorldHitTest = world.get_node("WorldHitTest")
    check(picker.reference_physics_body == player, "World hover picker must reference actual player physics canvas.")
    var bot_scene: CharacterBody2D = game.get_node("World/Enemy")
    var door_scene: Node2D = game.get_node("World/Door-0-0")
    check(bot_scene.z_index == player.z_index and bot_scene.get_node("Sprite").z_index == 0
        and bot_scene.get_node("CPUParticles2D").show_behind_parent,
        "Robot sprite must join player Y-sort layer, with its dust/shadow behind actors.")
    check(door_scene.z_index == player.z_index and door_scene.y_sort_enabled,
        "Open bulkhead must join character Y-sort layer to cover players walking behind it.")
    check(game._hover_target_name(player) == "player" and picker.interactable_layers & (1 << 9) != 0,
        "Player must remain identifiable by world hover like other interactive objects.")
    var viewport_point: Vector2 = picker.world_to_viewport(player.global_position)
    check(picker.viewport_to_world(viewport_point).distance_to(player.global_position) < 0.1, "World hover projection must invert Camera2D canvas transforms on original map.")
    var quantity: int = player.inventory.count(item)
    check(quantity >= 2, "Starter inventory should contain wires for world drops.")
    var reach_shape: CollisionShape2D = player.get_node("PlayerReach/CollisionShape2D")
    var reach_world_radius: float = reach_shape.shape.radius * reach_shape.global_scale.x
    check(absf(player.service_reach() - reach_world_radius) < 0.1,
        "Unaugmented world tool reach must match the original PlayerReach circle at World x3 scale.")
    var trash: InvItem = load("res://items/junk.tres")
    var robot: Node = game.get_node("World/Enemy")
    check(robot.drops != null and robot.drops.occupied() and Inv.matches(robot.drops.item, trash),
        "Defeated robot must yield the original trash-can item, never a missing placeholder.")
    var screen_point: Vector2 = picker.world_to_viewport(player.global_position + Vector2(30, 0))
    var old_children: int = world.get_child_count()
    check(screen_point.distance_to(picker.world_to_viewport(player.global_position)) > 0.0, "Drop target is projected into viewport space, not transformed twice.")
    game.mouse_over_ui = false
    game._handle_world_drop(player.inventory, player.inventory.find(item), item, screen_point)
    check(player.inventory.count(item) == quantity - 1, "World drop should remove exactly one wire from stack.")
    check(world.get_child_count() == old_children + 1, "One world object should be instantiated (no shadow HUD clone).")
    var created: Node = world.get_child(world.get_child_count() - 1)
    check(created.get("itemslot") != null and created.get("itemslot").count == 1, "Dropped world pickup carries exactly one physical item.")
    created.activate(player)
    check(player.inventory.count(item) == quantity, "Picking up the dropped object must restore its original count.")
    game.mouse_over_ui = true
    game.get_node("HUD/FullInventory").visible = true
    var ui_point: Vector2 = game.get_node("HUD/FullInventory").get_global_rect().get_center()
    game._handle_world_drop(player.inventory, player.inventory.find(item), item, ui_point)
    game.get_node("HUD/FullInventory").visible = false
    check(player.inventory.count(item) == quantity, "Item released over UI should never be dropped on the floor.")
    game.mouse_over_ui = false
    game._handle_world_drop(player.inventory, player.inventory.find(item), item, screen_point + Vector2(9000, 0))
    check(player.inventory.count(item) == quantity, "Out-of-reach world drop must preserve stock.")
    # World terminal must use the SAME physical backpack as the grid/mannequin.
    var terminal = game.get_node("World/Terminal")
    check(terminal.puzzle_type == "circuit", "Main-map terminal should offer electronic repair.")
    terminal.activate(player)
    var bench: CircuitWorkbench = terminal.ui_menu
    check(bench != null and bench.field_inventory == player.inventory, "Terminal workbench should bind actual player backpack.")
    game.toggle_inventory() # Tab while the circuit UI is open.
    check(not game.puzzle_active and not drawer.visible and game.get_node("HUD/QuickInventory").visible,
        "Tab must close the actual circuit puzzle, not only its inventory drawer.")
    check(terminal.ui_menu == null,
        "Closing the circuit must clear the terminal workbench reference.")
    terminal.activate(player)
    bench = terminal.ui_menu
    check(game.puzzle_active and bench != null,
        "Closed circuit must reopen cleanly without a stale overlay.")
    var canvas: CircuitBoardView = bench.board_view
    check(canvas._get_minimum_size() == Vector2.ZERO, "Infinite-looking circuit view must not shrink the board panel to authored cells.")
    canvas.size = Vector2(800, 440)
    canvas._center_on_authored_board()
    var resistor_center: Vector2 = canvas.pan_offset + Vector2(2.5, 1.5) * canvas.cell_size
    check(canvas._cell_from_position(resistor_center) == Vector2i(2, 1),
        "Native board drag/drop must translate displayed panning back into authored cell coordinates.")
    check(not canvas._inside(Vector2i(-1, 1)) and not canvas._inside(Vector2i(canvas.board.width, 1)),
        "Fake infinite-grid cells must never become valid electronic placements.")
    canvas.pan_by(Vector2(99999, -99999))
    var centre: Vector2 = canvas.size * 0.5 - canvas.pan_offset
    var extended: Vector2 = Vector2(canvas.board.width, canvas.board.height) * canvas.cell_size
    var pad: float = canvas.pan_limit_cells * canvas.cell_size
    check(centre.x >= -pad - 0.1 and centre.x <= extended.x + pad + 0.1
        and centre.y >= -pad - 0.1 and centre.y <= extended.y + pad + 0.1,
        "Middle-mouse board scrolling must stop no farther than twenty cells outside loaded data.")
    canvas.pan_needs_center = true
    canvas._center_on_authored_board()
    var prior_pan: Vector2 = canvas.pan_offset
    var middle_down := InputEventMouseButton.new()
    middle_down.button_index = MOUSE_BUTTON_MIDDLE
    middle_down.pressed = true
    canvas._gui_input(middle_down)
    var middle_motion := InputEventMouseMotion.new()
    middle_motion.relative = Vector2(19, -11)
    canvas._gui_input(middle_motion)
    check(canvas.middle_panning and canvas.pan_offset.distance_to(prior_pan + Vector2(19, -11)) < 0.5,
        "Middle-mouse motion must pan virtual grid, not operate or rotate components.")
    var middle_up := InputEventMouseButton.new()
    middle_up.button_index = MOUSE_BUTTON_MIDDLE
    middle_up.pressed = false
    canvas._gui_input(middle_up)
    check(not canvas.middle_panning, "Releasing middle mouse must stop panning.")
    canvas.pan_needs_center = true
    canvas._center_on_authored_board()
    var power: Button = bench.get_node("Panel/Padding/Layout/Bottom/RunButton")
    var power_style: StyleBoxFlat = power.get_theme_stylebox("normal")
    check(power_style.bg_color.r > power_style.bg_color.g * 2.0,
        "Circuit power switch must be visibly distinct with a red backed button.")
    check(game.puzzle_active and drawer.visible, "Circuit opening should preserve the same physical inventory grid.")
    print("HUD PUZZLE: drawer=", drawer.get_global_rect(), " board=", bench.get_global_rect(),
        " quick_visible=", game.get_node("HUD/QuickInventory").visible)
    check(drawer.position.x > 500.0 and not game.get_node("HUD/QuickInventory").visible,
        "Puzzle mode moves the drawer right and hides quick access.")
    check(game.get_node("HUD/TextBox").get_global_rect().position.x <= 10.0,
        "Event log should span the entire bottom edge during circuit repair.")
    check(bench.get_global_rect().end.x <= drawer.get_global_rect().position.x,
        "Large puzzle board must not draw underneath the inventory drawer.")
    var resistor: InvItem = load("res://items/resistor10.tres")
    check(resistor.texture is AtlasTexture and resistor.texture.get_size() == Vector2(16, 16)
        and resistor.texture.atlas.resource_path.ends_with("tileset_electronics.png"),
        "Inventory resistor icon must come from original hand-drawn resistor atlas at integer 3x size.")
    var pistol: InvItem = load("res://items/arc_pistol.tres")
    var pistol_before: int = player.inventory.count(pistol)
    var invalid_tool_drop: Dictionary = {"kind": "inventory_item", "item": pistol,
        "inventory": player.inventory, "index": player.inventory.find(pistol)}
    check(not canvas._can_drop_data(canvas.pan_offset + Vector2(4.5, 0.5) * canvas.cell_size, invalid_tool_drop),
        "A gun must never be accepted as a generic circuit replacement.")
    game._handle_world_drop(player.inventory, player.inventory.find(pistol), pistol,
        canvas.get_global_rect().get_center())
    check(player.inventory.count(pistol) == pistol_before,
        "A rejected circuit drop must never leak through the overlay or consume the gun.")
    var solder: InvItem = load("res://items/solder.tres")
    var resistor_before: int = player.inventory.count(resistor)
    var solder_before: int = player.inventory.count(solder)
    var cutters: InvItem = load("res://items/side_cutters.tres")
    # Burnt parts must be removed by physically applying pliers to the board;
    # the tool is retained and the broken piece becomes scrap.
    check(player.inventory.add_item(cutters, 1), "Player must be able to carry pliers to the panel.")
    var cutters_before: int = player.inventory.count(cutters)
    var tool_drop: Dictionary = {"kind": "inventory_item", "item": cutters,
        "inventory": player.inventory, "index": player.inventory.find(cutters)}
    var burnt_cell_position: Vector2 = bench.board_view.pan_offset + Vector2(2.5, 1.5) * bench.board_view.cell_size
    check(bench.board_view._can_drop_data(burnt_cell_position, tool_drop),
        "Burnt leads must accept cutters dragged directly from the backpack.")
    bench.board_view._drop_data(burnt_cell_position, tool_drop)
    check(bench.board.placement_at(Vector2i(2, 1)) < 0 and player.inventory.count(cutters) == cutters_before,
        "Snapping a burnt component must retain real cutters and leave an empty pad.")
    bench._install_inventory_part(resistor, Vector2i(2, 1))
    check(player.inventory.count(resistor) == resistor_before - 1, "Installing physical resistor should use one real item.")
    check(player.inventory.count(solder) == solder_before - 1, "Soldering should spend exactly one solder.")
    for tick in range(15):
        bench._on_simulation_tick()
    check(terminal.access_granted, "Electrically valid repair should grant legacy map terminal access.")
    check(terminal.ui_menu == null, "Solved repair should dismiss the workbench overlay.")
    check(not game.puzzle_active and game.get_node("HUD/QuickInventory").visible,
        "Closing the terminal should restore exploration quickbar and HUD.")
    var jumper: InvItem = load("res://items/wire_bridge.tres")
    var wire_model: CircuitPart = load("res://systems/circuits/parts/wire_straight.tres")
    check(jumper.circuit_part == wire_model, "Crafted jumper is mapped to a usable real circuit part.")
    # Cut/rebuild usable electronics: world backpack recipe -> actual circuit part.
    var wires: InvItem = load("res://items/wires.tres")
    var crafted: Dictionary = InventoryOperations.move_or_combine(
        player.inventory, player.inventory.find(wires), player.inventory, player.inventory.find(solder))
    check(bool(crafted.get("ok", false)) and player.inventory.count(jumper) == 1,
        "Wire plus solder must yield a real playable circuit jumper.")
    # A separately scavenged solder segment is required to INSTALL the crafted part.
    player.inventory.add_item(solder, 1)
    var second: CircuitWorkbench = load("res://systems/circuits/CircuitWorkbench.tscn").instantiate()
    game.get_node("HUD").add_child(second)
    second.set_field_inventory(player.inventory)
    second._install_inventory_part(jumper, Vector2i(4, 0))
    check(player.inventory.count(jumper) == 0 and second.board.placement_at(Vector2i(4, 0)) >= 0,
        "Crafted jumper should be consumed as an actual editable wire component.")
    check(player.inventory.count(solder) == 0, "Installing crafted jumper must additionally consume solder.")
    second.queue_free()
    game.queue_free()
    if failures == 0:
        print("WORLD INVENTORY TESTS PASSED")
        quit(0)
    else:
        push_error("%d WORLD INVENTORY TESTS FAILED" % failures)
        quit(1)
