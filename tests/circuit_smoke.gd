extends SceneTree

## Run: godot --headless --path . --script res://tests/circuit_smoke.gd
## Headless integration tests for voltage, open faults, topology and heat.
var failures: int = 0

func _initialize() -> void:
    test_open_and_repaired_actuator()
    test_insulated_crossover()
    test_thermal_failure()
    test_station_power_and_protocols()
    test_rotated_oversized_footprint()
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
    check(bool(station.device_online.get("maintenance_bulkhead", false)), "Valid protocol and DC + security should open door interlock.")
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
