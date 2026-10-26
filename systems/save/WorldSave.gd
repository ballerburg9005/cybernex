extends RefCounted
class_name WorldSave

## Save only JSON primitives. Item paths are resolved from this owned catalogue
## rather than arbitrary paths embedded in user:// files.
const VERSION: int = 1
const SAVE_PATH: String = "user://cybernex_save_v1.json"
const ITEM_NAMES := [
    "arc_pistol", "big_wire", "copper_contacts", "junk", "neural_regulator",
    "power_cell", "resistor10", "servo_brace", "side_cutters", "solder",
    "wire_bridge", "wires"
]

static func _catalogue() -> Dictionary:
    var items: Dictionary = {}
    for name in ITEM_NAMES:
        var resource: InvItem = load("res://items/%s.tres" % name)
        if resource != null:
            items[Inv.item_key(resource)] = resource
    return items

static func _capture_inventory(inventory: Inv) -> Array[Dictionary]:
    var entries: Array[Dictionary] = []
    for cell in inventory.items:
        if cell != null and cell.occupied():
            entries.append({"item": Inv.item_key(cell.item), "count": cell.count})
    return entries

static func _prepare_inventory(entries: Variant, capacity: int, limit: int, catalogue: Dictionary) -> Inv:
    if typeof(entries) != TYPE_ARRAY or capacity < 1 or capacity > 10000:
        return null
    var prepared := Inv.new(capacity)
    prepared.max_stack = limit
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            return null
        var id: String = str(entry.get("item", ""))
        var quantity: int = int(entry.get("count", 0))
        if not catalogue.has(id) or quantity < 1 or quantity > 100000:
            return null
        if not prepared.add_item(catalogue[id], quantity):
            return null
    return prepared

static func _quickbar_keys(bar: Inv) -> Array[String]:
    var keys: Array[String] = []
    for index in range(bar.size()):
        var slot: InvSlot = bar.slot_at(index)
        keys.append(Inv.item_key(slot.item) if slot != null else "")
    return keys

static func _prepare_quickbar(entries: Variant, backpack: Inv, size: int, catalogue: Dictionary) -> Inv:
    if typeof(entries) != TYPE_ARRAY or entries.size() != size:
        return null
    var hotbar := Inv.new(size)
    hotbar.auto_group_stacks = false
    for index in range(size):
        var key: String = str(entries[index])
        if key.is_empty():
            continue
        if not catalogue.has(key) or not backpack.has(catalogue[key]):
            return null
        hotbar.items[index] = InvSlot.new(catalogue[key], 1)
    return hotbar

static func _vector_from(data: Variant) -> Variant:
    if typeof(data) != TYPE_ARRAY or data.size() != 2:
        return null
    if typeof(data[0]) not in [TYPE_FLOAT, TYPE_INT] or typeof(data[1]) not in [TYPE_FLOAT, TYPE_INT]:
        return null
    var x: float = float(data[0])
    var y: float = float(data[1])
    if not is_finite(x) or not is_finite(y) or absf(x) > 100000.0 or absf(y) > 100000.0:
        return null
    return Vector2(x, y)

static func capture(game: Control) -> Dictionary:
    var actor: Node2D = game.get_node("World/Player")
    var world: Node2D = game.get_node("World")
    var entries: Dictionary = {}
    var pickups: Array[Dictionary] = []
    var robots: Dictionary = {}
    for node in world.get_children():
        if node is WorldItemPickup and node.itemslot != null and node.itemslot.occupied():
            pickups.append({
                "pos": [node.position.x, node.position.y],
                "item": Inv.item_key(node.itemslot.item),
                "count": node.itemslot.count
            })
        if node.has_method("play_activate") and "access_granted" in node and "loot" in node:
            entries[node.name] = {
                "access": node.access_granted, "active": node.is_activated,
                "loot": _capture_inventory(node.loot)
            }
        if node.is_in_group("enemies") and "health" in node:
            robots[node.name] = {
                "health": node.health,
                "pos": [node.position.x, node.position.y]
            }
    return {
        "version": VERSION,
        "player": {
            "position": [actor.position.x, actor.position.y],
            "health": actor.health,
            "equipment_energy": actor.equipment_runtime.snapshot()
        },
        "inventory": _capture_inventory(actor.inventory),
        "quickbar": _quickbar_keys(actor.quickinventory),
        "loadout": actor.equipment.snapshot(),
        "terminals": entries,
        "pickups": pickups,
        "enemies": robots
    }

static func restore(game: Control, data: Dictionary) -> bool:
    if int(data.get("version", -1)) != VERSION:
        return false
    var actor: Node2D = game.get_node("World/Player")
    var world: Node2D = game.get_node("World")
    var catalogue: Dictionary = _catalogue()
    var player_data: Variant = data.get("player")
    if typeof(player_data) != TYPE_DICTIONARY:
        return false
    var player_position: Variant = _vector_from(player_data.get("position"))
    var health: float = float(player_data.get("health", -1.0))
    if player_position == null or not is_finite(health) or health < 0.0 or health > 100.0:
        return false
    var new_bag: Inv = _prepare_inventory(data.get("inventory"), actor.inventory.size(), actor.inventory.max_stack, catalogue)
    if new_bag == null:
        return false
    var new_hotbar: Inv = _prepare_quickbar(data.get("quickbar"), new_bag, actor.quickinventory.size(), catalogue)
    if new_hotbar == null:
        return false
    var equipment_state: Variant = data.get("loadout")
    if typeof(equipment_state) != TYPE_DICTIONARY:
        return false
    var new_loadout := EquipmentLoadout.new()
    if not new_loadout.restore(equipment_state, new_bag):
        return false
    var new_energy := EquipmentRuntime.new()
    if not new_energy.restore(player_data.get("equipment_energy", {})):
        return false
    # Validate everything, including the complete world item manifest, before
    # any currently-live model changes.
    var terminal_states: Variant = data.get("terminals", {})
    if typeof(terminal_states) != TYPE_DICTIONARY:
        return false
    var next_terminals: Dictionary = {}
    for node_name in terminal_states:
        var node: Node = world.get_node_or_null(str(node_name))
        var record: Variant = terminal_states[node_name]
        if node == null or not node.has_method("play_activate") or typeof(record) != TYPE_DICTIONARY:
            return false
        var storage: Inv = _prepare_inventory(record.get("loot", []), node.loot.size(), node.loot.max_stack, catalogue)
        if storage == null:
            return false
        next_terminals[node_name] = {
            "node": node, "loot": storage,
            "access": bool(record.get("access", false)),
            "active": bool(record.get("active", false))
        }
    var pickup_entries: Variant = data.get("pickups")
    if typeof(pickup_entries) != TYPE_ARRAY or pickup_entries.size() > 2000:
        return false
    var saved_pickups: Array[Dictionary] = []
    for record in pickup_entries:
        if typeof(record) != TYPE_DICTIONARY:
            return false
        var pos: Variant = _vector_from(record.get("pos"))
        var id: String = str(record.get("item", ""))
        var quantity: int = int(record.get("count", 0))
        if pos == null or not catalogue.has(id) or quantity < 1 or quantity > 9999:
            return false
        saved_pickups.append({"position": pos, "item": catalogue[id], "count": quantity})
    var robot_states: Variant = data.get("enemies", {})
    if typeof(robot_states) != TYPE_DICTIONARY:
        return false
    var next_robots: Dictionary = {}
    for robot_name in robot_states:
        var robot: Node = world.get_node_or_null(str(robot_name))
        var record: Variant = robot_states[robot_name]
        if robot == null or not robot.is_in_group("enemies") or typeof(record) != TYPE_DICTIONARY:
            return false
        var pos: Variant = _vector_from(record.get("pos"))
        var hp: float = float(record.get("health", -1.0))
        if pos == null or not is_finite(hp) or hp < 0.0 or hp > 10000.0:
            return false
        next_robots[robot_name] = {"node": robot, "pos": pos, "health": hp}

    # Everything validated; commit models and recreate world pickups.
    actor.inventory = new_bag
    actor.quickinventory = new_hotbar
    actor.equipment = new_loadout
    actor.equipment_runtime = new_energy
    actor.position = player_position
    actor.health = health
    actor.last_health = health
    for key in next_terminals:
        var record: Dictionary = next_terminals[key]
        var terminal: Node = record["node"]
        terminal.loot = record["loot"]
        terminal.access_granted = record["access"]
        terminal.has_loot = terminal.loot.count() > 0
        terminal.playing_first_time = true
        if record["active"]:
            terminal.play_activate(true)
        else:
            terminal.play_deactivate(true)
        terminal.is_activated = record["active"]
    for node in world.get_children():
        if node is WorldItemPickup:
            world.remove_child(node)
            node.queue_free()
        if node.is_in_group("enemies"):
            if not next_robots.has(node.name):
                world.remove_child(node)
                node.queue_free()
            else:
                node.position = next_robots[node.name]["pos"]
                node.health = next_robots[node.name]["health"]
    var prefab: PackedScene = preload("res://items/item_world.tscn")
    for pickup in saved_pickups:
        var obj: WorldItemPickup = prefab.instantiate()
        obj.itemslot = InvSlot.new(pickup["item"], pickup["count"])
        world.add_child(obj)
        obj.position = pickup["position"]
    return true

static func write(game: Control, path: String = SAVE_PATH) -> bool:
    var snapshot: Dictionary = capture(game)
    var encoded: String = JSON.stringify(snapshot)
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(encoded)
    file.close()
    return true

static func read(game: Control, path: String = SAVE_PATH) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return false
    var serialized: String = file.get_as_text()
    file.close()
    if serialized.length() > 4000000:
        return false
    var decoded: Variant = JSON.parse_string(serialized)
    return typeof(decoded) == TYPE_DICTIONARY and restore(game, decoded)
