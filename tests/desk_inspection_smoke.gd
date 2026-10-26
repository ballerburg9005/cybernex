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
    check(panel != null and panel == desk.ui_menu, "Legacy desk must open shared modular inspection.")
    check(panel.is_inside_tree() and panel.get_parent() == game.get_node("HUD"),
        "Desk inspection must be a viewport HUD Control, not a world-space popup.")
    check(panel.get_global_rect().position.x >= 0 and panel.get_global_rect().end.x <= 1280,
        "Desk inspection must be wholly within 720p width.")
    check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= 720,
        "Desk inspection must be wholly within 720p height.")
    check(panel.bag_view.inv == player.inventory and panel.desk_view.inv == desk.loot,
        "Desk and backpack must show two actual physical inventory models at the same time.")
    check(panel.bag_view.visible and panel.desk_view.visible, "Contents page must show desk and player pack.")
    var cutters: InvItem = load("res://items/side_cutters.tres")
    var cutter_count: int = player.inventory.count(cutters)
    var inside: Vector2 = panel.get_global_rect().get_center()
    game._handle_world_drop(player.inventory, player.inventory.find(cutters), cutters, inside)
    check(player.inventory.count(cutters) == cutter_count,
        "Physical tools dropped onto ANY chest panel area must not leak into world.")
    panel._select_page(1)
    check(panel.bag_view.visible and panel.get_node("Layout/Contents/DetailPanel").visible,
        "Notes page must keep actual backpack visible alongside inspection pane.")
    panel._select_page(2)
    panel.toggle_power()
    check(not panel.computer_powered and game.hud_textbox.text.contains("PC shuts off."),
        "Computer page must route machine action to lower accessible event journal.")
    panel._select_page(0)
    var player_before: int = player.inventory.count()
    check(panel.take_all(), "TAKE ALL should transfer compatible real desk contents.")
    check(player.inventory.count() == player_before + initial_count and desk.loot.count() == 0,
        "Desk Take All must conserve exactly the same physical item quantities.")
    panel.close()
    check(game.desk_inspection == null, "Closing a desk frees its modal capture.")
    check(not game.ui_captures_world_input(), "Closing desk restores normal world action keys.")
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
