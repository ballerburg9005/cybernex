extends SceneTree

## Run: godot --headless --path . --script res://tests/circuit_smoke.gd
## Headless integration tests for voltage, open faults, topology and heat.
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    test_open_and_repaired_actuator()
    test_insulated_crossover()
    test_thermal_failure()
    test_station_power_and_protocols()
    test_rotated_oversized_footprint()
    test_original_sprite_geometry_and_taped_joint()
    test_tool_as_removable_electrical_bridge()
    test_transactional_inventory()
    test_capacitor_and_inductor_transients()
    test_playable_maintenance_chain()
    if failures > 0:
        push_error("%d CIRCUIT TESTS FAILED" % failures)
        quit(1)
    else:
        print("CIRCUIT TESTS PASSED")
        quit(0)

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func base_board() -> CircuitBoard:
    var original: CircuitBoard = load("res://systems/circuits/boards/door_actuator.tres")
    return original.duplicate(true)

func test_open_and_repaired_actuator() -> void:
    var board: CircuitBoard = base_board()
    var simulation := CircuitSimulation.new()
    var open_result: Dictionary = simulation.step(board, 1.0)
    print("OPEN STATE: ", open_result["loads"], " faults=", board.placements[1].failed_open)
    check(open_result["errors"].is_empty(), "Burned resistor should still make a valid circuit.")
    check(absf(float(open_result["loads"].get("door_motor", 99.0))) < 0.01, "Burned series resistor must block load voltage.")
    check(not open_result["solved"], "Open actuator must not solve.")
    board.placements[1].failed_open = false
    simulation = CircuitSimulation.new()
    var result: Dictionary = simulation.step(board, 1.0)
    var volts: float = float(result["loads"].get("door_motor", -1.0))
    check(result["errors"].is_empty(), "Repair should yield convergent DC solution.")
    check(absf(volts - 4.533) < 0.03, "Expected Ohm's law ~4.533 V at 100 ohm load, got %.4f" % volts)
    check(result["solved"], "Repaired actuator within 4V..5.2V must unlock.")

func test_insulated_crossover() -> void:
    var board := CircuitBoard.new()
    board.width = 3
    board.height = 3
    var cross := CircuitPlacement.new()
    cross.part = load("res://systems/circuits/parts/wire_crossover.tres")
    cross.cell = Vector2i(1, 1)
    var ground := CircuitPlacement.new()
    ground.part = load("res://systems/circuits/parts/ground.tres")
    ground.cell = Vector2i(1, 0)
    ground.rotation = 2
    board.placements = [cross, ground]
    var compiled: Dictionary = CircuitCompiler.compile(board)
    check(compiled["errors"].is_empty(), "Crossover board must validate.")
    var x_node: int = -1
    var y_node: int = -1
    for e in compiled["elements"]:
        if e["id"] == "0:0":
            x_node = e["b"]
        if e["id"] == "0:2":
            y_node = e["b"]
    check(x_node >= 0 and y_node >= 0 and x_node != y_node, "Insulated crossed wires must have independent hub nodes.")

func test_thermal_failure() -> void:
    var board: CircuitBoard = base_board()
    board.placements[1].failed_open = false
    var fragile: CircuitPart = board.placements[1].part.duplicate(true)
    fragile.thermal_capacity = 0.001
    fragile.cooling_watts_per_kelvin = 0.001
    fragile.failure_temperature_c = 25.0
    board.placements[1].part = fragile
    var simulation := CircuitSimulation.new()
    var result: Dictionary = simulation.step(board, 1.0)
    check(result["errors"].is_empty(), "Overheating test should be electrically solvable.")
    check(board.placements[1].failed_open, "Excess Joule heat should burn component open.")

func test_station_power_and_protocols() -> void:
    var station: StationNetwork = load("res://systems/station/StationNetworkDemo.tscn").instantiate()
    station.evaluate()
    check(bool(station.device_online.get("rectifier_ac_to_dc", false)), "AC->DC converter must supply the isolated DC bus.")
    check(bool(station.device_online.get("security_controller", false)), "Security controller needs DC feed.")
    check(not bool(station.device_online.get("maintenance_bulkhead", false)), "Power must not bypass security protocol.")
    station.grant_protocol("SEC_BULKHEAD_7", true)
    check(not bool(station.device_online.get("maintenance_bulkhead", false)), "A protocol must not bypass the failed actuator driver.")
    station.set_repaired_module("door_driver", true)
    check(not bool(station.device_online.get("maintenance_bulkhead", false)), "Working hardware must not bypass unsafe atmosphere.")
    station.set_condition("safe_atmosphere", true)
    check(bool(station.device_online.get("maintenance_bulkhead", false)), "Power, protocol, driver and environment together enable the door.")
    station.damage_device("rectifier_ac_to_dc")
    check(not bool(station.device_online.get("security_controller", false)), "Converter loss should remove DC supply.")
    check(not bool(station.device_online.get("maintenance_bulkhead", false)), "Previously authenticated bulkhead must still require power.")
    station.time_seconds = 2.0
    station.evaluate()
    check(not bool(station.bus_online.get("PULSE_HV", true)), "Pulsed rail must observe configured duty cycle.")
    station.free()

func test_rotated_oversized_footprint() -> void:
    var part := CircuitPart.new()
    part.footprint = Vector2i(2, 1)
    var pin := CircuitPin.new()
    pin.side = 2
    pin.offset = 0
    part.pins.append(pin)
    var placement := CircuitPlacement.new()
    placement.part = part
    placement.cell = Vector2i(3, 3)
    placement.rotation = 1
    check(placement.footprint() == Vector2i(1, 2), "90 degree rotation must swap wide footprint dimensions.")
    var rotated: Dictionary = placement.rotated_pin(pin)
    check(rotated["cell"] == Vector2i(3, 4) and rotated["side"] == 3, "Rotated right pin must become bottom pin at far cell.")

func test_transactional_inventory() -> void:
    var inventory: SalvageInventory = load("res://systems/inventory/field_inventory.tres").duplicate(true)
    var req := MaterialRequirement.new()
    req.item_id = "solder"
    req.quantity = 2
    check(not inventory.consume([req]), "Insufficient solder must not permit a partial payment.")
    check(inventory.amount("solder") == 1, "Failed material transaction must leave stock untouched.")
    check(not inventory.consume([req], PackedStringArray(["robertson_2"])), "Missing specialist tool must prevent repair.")
    inventory.add_tool("robertson_2", "Robertson #2")
    inventory.add("solder", 3)
    check(inventory.consume([req], PackedStringArray(["robertson_2"])), "Stock plus correct tool should permit repair.")
    check(inventory.has_tool("robertson_2"), "Reusable screwdriver should not be consumed.")
    var snap: Dictionary = inventory.snapshot()
    var fresh := SalvageInventory.new()
    fresh.restore(snap)
    check(fresh.amount("solder") == 2 and fresh.has_tool("robertson_2"), "Save restore should preserve dynamically acquired tools.")

func test_playable_maintenance_chain() -> void:
    var scene: PackedScene = load("res://systems/station/StationMaintenanceBay.tscn")
    check(scene != null, "Maintenance bay scene should import.")
    if scene == null:
        return
    var bay: StationMaintenanceBay = scene.instantiate()
    root.add_child(bay)
    check(not bool(bay.station.device_online.get("maintenance_bulkhead", false)), "First arrival: bulkhead should remain locked.")
    check(not bay.repair_ventilation(), "Repairing live switchgear must fail.")
    bay.isolate_ac()
    check(not bay.repair_ventilation(), "Repair must still require specialist screwdriver and supplies.")
    check(bay.search_service_deck(), "Scavenging trip should obtain necessary repair tools.")
    check(bay.repair_ventilation(), "Repair should work after lockout and stock acquisition.")
    bay.restore_ac()
    check(bool(bay.station.device_online.get("ventilation_drive", false)), "Restored industrial power must run repaired ventilation.")
    check(bay.recover_protocol_trace(), "Powered security controller should yield recoverable credentials.")
    check(bay.authorize_bulkhead(), "Captured protocol and analyzer should authorize the PLC.")
    check(not bool(bay.station.device_online.get("maintenance_bulkhead", false)), "PLC success must not bypass unsolved circuit and unsafe air.")
    var bench: CircuitWorkbench = bay.workbench
    bench.selected_index = 1
    bench._remove_selected()
    bench.palette.select(0)
    bench._on_board_click(Vector2i(2, 1))
    check(bench.board.placements.size() == 5, "Bench should install one salvaged resistor.")
    for i in range(14):
        bench._on_simulation_tick()
    check(bool(bay.station.repaired_modules.get("door_driver", false)), "Actual solved electrical circuit should assert hardware diagnostic.")
    check(bay.close_gas_valve(), "Physical screwdriver should isolate the AI gas valve.")
    bay.advance_station(150.0)
    check(bay.atmosphere.is_safe(), "Repaired ventilation must restore a breathable atmosphere after gas injection.")
    check(bay.try_open_door(), "Door must open only after every independent condition is satisfied.")
    var snapshot: Dictionary = bay.build_snapshot()
    bay.station.damage_device("rectifier_ac_to_dc")
    check(not bool(bay.station.device_online.get("maintenance_bulkhead", false)), "Power converter fault must re-lock systems.")
    check(bay.apply_snapshot(snapshot), "Scene should restore a serializable maintenance snapshot.")
    check(bool(bay.station.device_online.get("maintenance_bulkhead", false)), "Restored converter and interlocks must restore bulkhead status.")
    bay.free()

func test_capacitor_and_inductor_transients() -> void:
    var board: CircuitBoard = base_board()
    board.placements[1].part = load("res://systems/circuits/parts/capacitor_20mf.tres")
    board.placements[1].failed_open = false
    var simulator := CircuitSimulation.new()
    var result: Dictionary = simulator.step(board, 0.05)
    var first: float = float(result["loads"].get("door_motor", -1.0))
    check(result["errors"].is_empty(), "RC startup must produce finite node voltages.")
    check(first > 4.0, "Initially uncharged 20mF series capacitor should pass a charging pulse.")
    for i in range(250):
        result = simulator.step(board, 0.05)
    var later: float = float(result["loads"].get("door_motor", -1.0))
    check(later < 0.1, "DC current through charged series capacitor must decay to near zero.")
    board = base_board()
    board.placements[1].part = load("res://systems/circuits/parts/inductor_100h.tres")
    board.placements[1].failed_open = false
    simulator = CircuitSimulation.new()
    result = simulator.step(board, 0.05)
    first = float(result["loads"].get("door_motor", -1.0))
    check(result["errors"].is_empty(), "RL startup must produce finite node voltages.")
    check(first < 0.5, "100H inductor must oppose immediate current change.")
    for i in range(250):
        result = simulator.step(board, 0.05)
    later = float(result["loads"].get("door_motor", -1.0))
    check(later > 4.5, "DC current through a settled inductor should approach resistive steady state.")

func test_original_sprite_geometry_and_taped_joint() -> void:
    var resistor: CircuitPart = load("res://systems/circuits/parts/resistor_10.tres")
    var mosfet: CircuitPart = load("res://systems/circuits/parts/nmos.tres")
    check(resistor.sprite != null and resistor.sprite.get_size() == Vector2(32, 16),
        "Original hand-drawn 32x16 resistor art must survive into new circuit model.")
    check(mosfet.sprite != null and mosfet.sprite.get_size() == Vector2(32, 32),
        "New board must draw original hand-drawn 32x32 MOSFET art.")
    check(mosfet.footprint == Vector2i(2, 2), "MOSFET occupies original two-by-two cells.")
    var rotated := CircuitPlacement.new()
    rotated.part = mosfet
    rotated.cell = Vector2i(4, 3)
    rotated.rotation = 1
    check(rotated.footprint() == Vector2i(2, 2), "MOSFET rotation preserves oversized footprint.")
    var gate: Dictionary = rotated.rotated_pin(mosfet.pins[0])
    var drain: Dictionary = rotated.rotated_pin(mosfet.pins[1])
    check(gate["cell"] == Vector2i(4, 3) and gate["side"] == 1,
        "Rotated gate must appear on expected upper lead rather than central cell.")
    check(drain["cell"] == Vector2i(4, 4) and drain["side"] == 3,
        "Rotated MOSFET drain must appear on lower lead cell.")
    var pack := Inv.new(7)
    var tape: InvItem = load("res://items/insulation_tape.tres")
    var bridge: InvItem = load("res://items/wire_bridge.tres")
    pack.add_item(bridge, 1)
    pack.add_item(tape, 1)
    var scene: PackedScene = load("res://systems/circuits/CircuitWorkbench.tscn")
    var workbench: CircuitWorkbench = scene.instantiate()
    root.add_child(workbench)
    workbench.set_field_inventory(pack)
    var before: int = workbench.board.placements.size()
    workbench._install_inventory_part(bridge, Vector2i(5, 4))
    check(workbench.board.placements.size() == before + 1, "Insulating tape should attach a wire without solder.")
    check(pack.count(tape) == 0 and pack.count(bridge) == 0, "Tape and actual jumper must both be consumed exactly once.")
    if workbench.board.placements.size() == before + 1:
        var joint: CircuitPlacement = workbench.board.placements.back()
        check(joint.joint_resistance_ohms >= 0.30, "Taped cold splice must have explicit electrical contact penalty.")
        var network: Dictionary = CircuitCompiler.compile(workbench.board)
        var found_resistance: bool = false
        for element in network["elements"]:
            if int(element["part_index"]) == before and element.has("ohms"):
                found_resistance = found_resistance or float(element["ohms"]) > 0.15
        check(found_resistance, "Circuit solver must include the tape penalty in real resistor branches.")
        var record: Dictionary = workbench.snapshot()
        joint.joint_resistance_ohms = 0.0
        check(workbench.restore(record), "Taped splice must roundtrip through board snapshot.")
        check(workbench.board.placements.back().joint_resistance_ohms > 0.3, "Joint quality survives save/load.")
    workbench.queue_free()

func test_tool_as_removable_electrical_bridge() -> void:
    var scene: PackedScene = load("res://systems/circuits/CircuitWorkbench.tscn")
    var bench: CircuitWorkbench = scene.instantiate()
    root.add_child(bench)
    var bag := Inv.new(12)
    var pliers: InvItem = load("res://items/side_cutters.tres")
    var gun: InvItem = load("res://items/arc_pistol.tres")
    bag.add_item(pliers, 1)
    bag.add_item(gun, 1)
    bench.set_field_inventory(bag)
    var no_conductor: Vector2i = Vector2i(5, 5)
    check(not bench.can_bridge_with_tool(gun, Vector2i(2, 1)),
        "Nonconductive gun must not be treated as an improvised jumper.")
    check(not bench.can_bridge_with_tool(pliers, no_conductor),
        "Loose metal tools only connect exposed *opposing* real terminals.")
    check(not bench.can_bridge_with_tool(pliers, Vector2i(2, 1)),
        "Burnt resistor must be cut out before any bridge can fit the footprint.")
    bench.selected_index = 1
    bench._remove_selected()
    check(bench.board.placement_at(Vector2i(2, 1)) < 0,
        "Side cutters can snap the broken resistor without consuming cutters.")
    check(bench.can_bridge_with_tool(pliers, Vector2i(2, 1)),
        "Exposed source-to-motor pad admits a conductive metal tool.")
    var drop: Dictionary = {"kind": "inventory_item", "item": pliers, "inventory": bag,
        "index": bag.find(pliers)}
    var coordinate: Vector2 = bench.board_view.pan_offset + Vector2(2.5, 1.5) * bench.board_view.cell_size
    check(bench.board_view._can_drop_data(coordinate, drop),
        "Real native inventory drag target must accept side cutters as a contact bridge.")
    bench.board_view._drop_data(coordinate, drop)
    var idx: int = bench.board.placement_at(Vector2i(2, 1))
    check(idx >= 0 and bag.count(pliers) == 0 and bag.count(gun) == 1,
        "Real metal tool must leave backpack during contact and not disturb other stock.")
    if idx >= 0:
        var contact: CircuitPlacement = bench.board.placements[idx]
        check(contact.held_item_id == pliers.item_id and contact.part.model == "wire",
            "Bridge must persist the actual held tool identity, not fabricate a spare resistor.")
        check(absf(contact.part.value - pliers.contact_resistance_ohms) < 0.001,
            "Contact has physical tool-specific resistance, not an ideal short.")
        var outcome: Dictionary = CircuitSimulation.new().step(bench.board, 0.5)
        check(outcome["errors"].is_empty() and float(outcome["loads"].get("door_motor", -1.0)) > 4.0,
            "Metal tool must carry modeled electrical current and deliver realistic voltage.")
        var snapshot: Dictionary = bench.snapshot()
        check(snapshot["placements"].back()["held_item"] == pliers.item_id,
            "Tool remains recoverable after station world-save serialization.")
        check(bench.restore(snapshot), "Valid tool contact must restore from board save state.")
        check(not bench.restore({"placements": [{
            "part_id": "contact_forged", "x": 2, "y": 1, "held_item": "forged",
            "rotation": 0, "fixed": false, "failed": false, "joint": 0.0
        }]}), "Forged contact tool identity must not load arbitrary unknown resources.")
        check(bench.restore(snapshot), "Valid snapshot must still load after rejection.")
        var restore_index: int = bench.board.placement_at(Vector2i(2, 1))
        check(bench.extract_to_backpack(restore_index, bag),
            "Tool can be lifted away from deenergized board without fresh solder.")
        check(bag.count(pliers) == 1 and bag.count(gun) == 1,
            "Returning tool must restore exactly one physical item, without duplication.")
        check(bench.board.placement_at(Vector2i(2, 1)) < 0,
            "Removing improvised bridge leaves original exposed electrical gap.")
    bench.queue_free()
