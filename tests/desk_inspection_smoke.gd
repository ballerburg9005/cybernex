extends SceneTree

var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(good: bool, reason: String) -> void:
    if not good:
        failures += 1
        push_error(reason)

func _run() -> void:
    root.size = Vector2i(1280, 720)
    var game: Control = load("res://main.tscn").instantiate()
    root.add_child(game)
    var player: CharacterBody2D = game.get_node("World/Player")
    var desk: Node = game.get_node("World/Desk")
    var initial_count: int = desk.loot.count()
    check(initial_count > 0, "Desk on original map must contain actual salvage.")
    desk.activate(player)
    var panel: DeskInspection = game.desk_inspection
    await process_frame # Native HBox sorting is deferred until after instantiation.
    check(panel != null and panel == desk.ui_menu and panel == game.desk_inspection_cache,
        "Desk should open one shared, already-created inspection pane without inventory rebuild.")
    check(panel.is_inside_tree() and panel.get_parent() == game.get_node("HUD"),
        "Desk inspection must be a viewport HUD Control, not a world-space popup.")
    check(panel.get_global_rect().position.x >= 0 and panel.get_global_rect().end.x <= 1280,
        "Desk inspection must be wholly within 720p width.")
    check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= 720,
        "Desk inspection must be wholly within 720p height.")
    check(panel.bag_view.inv == player.inventory and panel.desk_view.inv == desk.loot,
        "Desk and backpack must show two actual physical inventory models at the same time.")
    check(panel.bag_view.visible and panel.desk_view.visible, "Contents page must show desk and player pack.")
    print("DESK COLUMNS: bag=", panel.bag_view.get_global_rect(), " desk=", panel.desk_view.get_global_rect())
    var left_window: Control = panel.get_node("Columns/BackpackPanel")
    var right_window: Control = panel.get_node("Columns/DeskPanel")
    check(left_window.get_global_rect().end.x + 10.0 <= right_window.get_global_rect().position.x,
        "Backpack and desk should be TWO clearly separated background windows.")
    check(panel.bag_view.get_global_rect().end.x <= panel.desk_view.get_global_rect().position.x + 5.0,
        "Desk screen must have original backpack on LEFT and pageable desk contents on RIGHT.")
    check(panel.get_node("Columns/DeskPanel/Layout/Navigation/Page").get_theme_font_size("font_size") >= 28
        and panel.get_node("Columns/DeskPanel/Layout/Contents/DetailPanel/Description").get_theme_font_size("normal_font_size") >= 36,
        "Desk note and computer text should be large and readable with same page-nav hierarchy.")
    var cutters: InvItem = load("res://items/side_cutters.tres")
    var cutter_count: int = player.inventory.count(cutters)
    var inside: Vector2 = panel.get_global_rect().get_center()
    game._handle_world_drop(player.inventory, player.inventory.find(cutters), cutters, inside)
    check(player.inventory.count(cutters) == cutter_count,
        "Physical tools dropped onto ANY chest panel area must not leak into world.")
    panel._select_page(1)
    check(panel.bag_view.visible and panel.get_node("Columns/DeskPanel/Layout/Contents/DetailPanel").visible,
        "Notes page must keep actual backpack visible alongside inspection pane.")
    check(panel.get_node("Columns/DeskPanel/Layout/Contents/DetailPanel/Description").text.contains("dosimeter"),
        "Desk notes should be authored evidence from this actual desk, not generic UI help.")
    panel._select_page(2)
    var crt: RichTextLabel = panel.get_node("Columns/DeskPanel/Layout/Contents/DetailPanel/Description")
    check(crt.get_theme_color("default_color").g > crt.get_theme_color("default_color").r,
        "Powered workstation should use phosphor GREEN text instead of white instructions.")
    var power_button: Button = panel.get_node("Columns/DeskPanel/Layout/Bottom/Power")
    check(power_button.visible and power_button.has_theme_stylebox_override("normal"),
        "POWER must be a visible rounded red button, not bare text.")
    check(panel.get_node("Columns/DeskPanel/Layout/Contents/DetailPanel/Description").text.contains("RAD-MON"),
        "Desk computer should show its own signal/text log while powered on.")
    panel.toggle_power()
    check(not panel.computer_powered and not desk.computer_powered
        and game.hud_textbox.text.contains("PC shuts off."),
        "Computer page must persist power to desk and narrate change in accessible event journal.")
    panel._select_page(0)
    var player_before: int = player.inventory.count()
    check(panel.take_all(), "TAKE ALL should transfer compatible real desk contents.")
    check(player.inventory.count() == player_before + initial_count and desk.loot.count() == 0,
        "Desk Take All must conserve exactly the same physical item quantities.")
    panel.close()
    check(game.desk_inspection == null, "Closing a desk frees its modal capture.")
    check(not game.ui_captures_world_input(), "Closing desk restores normal world action keys.")
    var saved_desk: Dictionary = WorldSave.capture(game)
    check(saved_desk["terminals"]["Desk"]["computer_powered"] == false,
        "Versioned world save must capture each desk computer's actual power state.")
    desk.computer_powered = true
    check(WorldSave.restore(game, saved_desk) and not desk.computer_powered,
        "Loading the saved station must restore computer power before next inspection.")
    desk.activate(player)
    var revisited: DeskInspection = game.desk_inspection
    check(revisited != null and revisited.computer_powered == false,
        "Revisiting desk after save/load must show the real OFF condition.")
    if revisited != null:
        revisited._select_page(2)
        check(revisited.get_node("Columns/DeskPanel/Layout/Contents/DetailPanel/Description").text == "Black display.",
            "Unpowered desk terminal must not reveal computer data.")
        revisited.close()
    var other_desk: Node = game.get_node("World/Desk2")
    other_desk.activate(player)
    check(game.desk_inspection == panel and other_desk.ui_menu == panel
        and panel.authored_notes.contains("STAFF SHIFT CARD"),
        "Switching desks should REUSE the cached page while rebinding to that desk's authored evidence.")
    check(panel.bag_view.inv == player.inventory and panel.desk_view.inv == other_desk.loot,
        "Reused desk pane must point to the second desk's own physical loot and original backpack.")
    panel.close()
    var old_count: int = player.inventory.count(cutters)
    game.get_node("HUD/FullInventory").show()
    game._select_drawer_page(0)
    var title_position: Vector2 = game.get_node("HUD/FullInventory/VBoxContainer/DrawerNav").get_global_rect().get_center()
    game._handle_world_drop(player.inventory, player.inventory.find(cutters), cutters, title_position)
    check(player.inventory.count(cutters) == old_count,
        "Even navigation/header backdrops must intercept rejected world drops.")
    game.get_node("HUD/FullInventory").hide()
    game.queue_free()
    if failures == 0:
        print("DESK INSPECTION TESTS PASSED")
        quit(0)
    else:
        push_error("%d DESK INSPECTION TESTS FAILED" % failures)
        quit(1)
