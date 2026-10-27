extends Control
class_name StationMaintenanceBay

## A playable Godot-native integration scene, not a collection of magic
## "solved" flags. The workbench's electrical result, station's power budget,
## protocol state, oxygen safety and scarce tools are separate conditions.
@export var initial_inventory: SalvageInventory
@export var ventilation_procedure: RepairProcedure
@export var security_procedure: RepairProcedure

@onready var station: StationNetwork = %Station
@onready var atmosphere: StationAtmosphere = %Atmosphere
@onready var adversary: StationAdversary = %Adversary
@onready var workbench: CircuitWorkbench = %Workbench
@onready var diagnostics: RichTextLabel = %Diagnostics
@onready var stock_report: Label = %StockReport
@onready var journal: RichTextLabel = %Journal
@onready var clock: Timer = %SystemClock

var inventory: SalvageInventory
var visited_service_deck: bool = false
var recovered_security_trace: bool = false
var door_open: bool = false
var event_log: Array[String] = []

func _ready() -> void:
    inventory = initial_inventory.duplicate(true) if initial_inventory != null else SalvageInventory.new()
    station.evaluate()
    atmosphere.station = station
    adversary.station = station
    adversary.atmosphere = atmosphere
    workbench.set_inventory(inventory)
    workbench.puzzle_solved.connect(_on_circuit_proven)
    adversary.sabotage.connect(_log)
    %SearchDeck.pressed.connect(search_service_deck)
    %ArchiveTrace.pressed.connect(recover_protocol_trace)
    %CutPower.pressed.connect(isolate_ac)
    %RestorePower.pressed.connect(restore_ac)
    %RepairVent.pressed.connect(repair_ventilation)
    %Authenticate.pressed.connect(authorize_bulkhead)
    %CloseGas.pressed.connect(close_gas_valve)
    %OpenDoor.pressed.connect(try_open_door)
    %SaveProgress.pressed.connect(save_progress)
    %LoadProgress.pressed.connect(load_progress)
    clock.timeout.connect(_on_clock_tick)
    station.set_condition("safe_atmosphere", atmosphere.is_safe())
    _log("Maintenance bay: actuator broken, ventilation drive damaged, bulkhead unauthenticated.")
    _log("Note: the industrial AC feed also drives the rectifier for the 48V DC equipment.")
    clock.start()
    _refresh()

func _on_clock_tick() -> void:
    advance_station(clock.wait_time)

func advance_station(seconds: float) -> void:
    # Fixed substeps prevent player-initiated backtracking from skipping
    # atmosphere/AI changes while other station systems advance.
    var remaining: float = maxf(0.0, seconds)
    while remaining > 0.00001:
        var dt: float = minf(remaining, 0.25)
        station.time_seconds += dt
        station.evaluate()
        adversary.step(dt)
        atmosphere.step(dt)
        station.set_condition("safe_atmosphere", atmosphere.is_safe())
        remaining -= dt
    _refresh()

func search_service_deck() -> bool:
    if visited_service_deck:
        _log("Deck 3 stores have already been scavenged.")
        return false
    visited_service_deck = true
    adversary.player_detected = true
    inventory.add_tool("robertson_2", "Robertson #2 security screwdriver")
    inventory.add("solder", 2, "Solder segments")
    inventory.add("wire_length", 2, "Loose wiring")
    _log("Returned from maintenance deck 3 with a Robertson driver, 2 solder pieces and wiring.")
    advance_station(18.0)
    return true

func recover_protocol_trace() -> bool:
    if recovered_security_trace:
        _log("The archived PLC challenge has already been copied.")
        return false
    if not bool(station.device_online.get("security_controller", false)):
        _log("Security archive inaccessible: its DC security controller has no power.")
        return false
    recovered_security_trace = true
    adversary.player_detected = true
    inventory.add_tool("protocol_probe", "Recovered service bus analyzer")
    _log("Captured a maintenance-service protocol trace. AI sensor polling increased.")
    advance_station(8.0)
    return true

func isolate_ac() -> void:
    station.set_bus_enabled("AC_400", false)
    _log("Industrial AC isolated. The DC rectifier and ventilation are now unpowered.")
    advance_station(1.0)

func restore_ac() -> void:
    station.set_bus_enabled("AC_400", true)
    _log("Industrial AC restored; converters, ventilation and interlocks re-evaluate.")
    advance_station(1.0)

func repair_ventilation() -> bool:
    if ventilation_procedure == null:
        return false
    if bool(station._find_device(ventilation_procedure.target_device_id).intact):
        _log("Ventilation drive's contactor has already been repaired.")
        return false
    if ventilation_procedure.requires_power_isolated and bool(station.bus_online.get("AC_400", false)):
        _log("Repair refused: isolate the industrial AC bus before opening live switchgear.")
        return false
    var needed: PackedStringArray = inventory.missing(
        ventilation_procedure.needs_materials, ventilation_procedure.needs_tools)
    if not needed.is_empty():
        _log("Repair blocked; missing " + ", ".join(needed))
        return false
    if not inventory.consume(ventilation_procedure.needs_materials, ventilation_procedure.needs_tools):
        return false
    station.repair_device(ventilation_procedure.target_device_id)
    _log("Ventilation drive rewired. Solder and cable consumed; service tools retained.")
    advance_station(4.0)
    return true

func authorize_bulkhead() -> bool:
    if security_procedure == null:
        return false
    if not bool(station.device_online.get(security_procedure.target_device_id, false)):
        _log("Protocol injection failed: security controller is offline.")
        return false
    var missing: PackedStringArray = inventory.missing(
        security_procedure.needs_materials, security_procedure.needs_tools)
    if not missing.is_empty():
        _log("Protocol injection blocked; missing " + ", ".join(missing))
        return false
    if not inventory.consume(security_procedure.needs_materials, security_procedure.needs_tools):
        return false
    station.grant_protocol(security_procedure.granted_protocol, true)
    adversary.player_detected = true
    _log("Service handshake accepted. This does NOT repair the relay driver or bypass pressure safety.")
    advance_station(2.0)
    return true

func close_gas_valve() -> bool:
    if not inventory.has_tool("robertson_2"):
        _log("The gas valve has a Robertson #2 service screw. No compatible driver.")
        return false
    station.set_device_enabled(adversary.gas_injector_device_id, false)
    adversary.isolate_gas()
    _log("Gas injection mechanically isolated; ventilation must still purge accumulated gas.")
    advance_station(4.0)
    return true

func try_open_door() -> bool:
    station.evaluate()
    if door_open:
        _log("Bulkhead already unlocked.")
        return true
    if not bool(station.device_online.get("maintenance_bulkhead", false)):
        _log("BULKHEAD REFUSED: " + str(station.denial_reasons.get("maintenance_bulkhead", "Unknown fault")))
        return false
    door_open = true
    _log("BULKHEAD OPEN. Actuator voltage, DC feed, security handshake and atmosphere interlock are valid.")
    _refresh()
    return true

func _on_circuit_proven() -> void:
    station.set_repaired_module("door_driver", true)
    _log("Door relay board passed its timed voltage test. Station control recognizes the repaired driver.")
    _refresh()

func _log(message: String) -> void:
    event_log.append("[%05.1fs] %s" % [station.time_seconds, message])
    if event_log.size() > 35:
        event_log.pop_front()
    if is_node_ready():
        journal.text = "\n".join(event_log)

func _refresh() -> void:
    if not is_node_ready():
        return
    stock_report.text = inventory.describe() if inventory != null else "(empty)"
    var lines := PackedStringArray()
    for id in ["rectifier_ac_to_dc", "ventilation_drive", "security_controller",
            "security_gas_valve", "maintenance_bulkhead", "robot_charge_station"]:
        var online: bool = bool(station.device_online.get(id, false))
        var diagnostic: String = "ON" if online else str(station.denial_reasons.get(id, "OFF"))
        lines.append("%s: %s" % [id, diagnostic])
    lines.append("48V domain: %s" % ("LIVE" if station.bus_online.get("DC_48", false) else "DEAD"))
    lines.append("Air O2: %.1f%% | hazardous gas: %.1f%%" % [
        atmosphere.oxygen_fraction * 100.0, atmosphere.hazard_fraction * 100.0])
    lines.append("Security AI gas actions remaining: %d" % adversary.actions_remaining)
    lines.append("BULKHEAD: %s" % ("OPEN" if door_open else "CLOSED"))
    diagnostics.text = "\n".join(lines)
    journal.text = "\n".join(event_log)

func build_snapshot() -> Dictionary:
    return {
        "version": 1, "inventory": inventory.snapshot(),
        "station": station.snapshot(), "atmosphere": atmosphere.snapshot(),
        "adversary": adversary.snapshot(), "circuit": workbench.snapshot(),
        "visited_deck": visited_service_deck,
        "recovered_trace": recovered_security_trace, "door_open": door_open,
        "log": event_log.duplicate()
    }

func apply_snapshot(data: Dictionary) -> bool:
    if int(data.get("version", 0)) != 1:
        return false
    # Validate circuit data before mutating the remaining station state.
    if not workbench.restore(data.get("circuit", {})):
        return false
    inventory.restore(data.get("inventory", {}))
    station.restore(data.get("station", {}))
    atmosphere.restore(data.get("atmosphere", {}))
    adversary.restore(data.get("adversary", {}))
    visited_service_deck = bool(data.get("visited_deck", false))
    recovered_security_trace = bool(data.get("recovered_trace", false))
    door_open = bool(data.get("door_open", false))
    event_log.clear()
    for event in data.get("log", []):
        event_log.append(str(event))
    station.set_condition("safe_atmosphere", atmosphere.is_safe())
    workbench.set_inventory(inventory)
    _log("Snapshot restored. The circuit must be energized again to validate further edits.")
    _refresh()
    return true

func save_progress() -> void:
    var file: FileAccess = FileAccess.open("user://maintenance_bay_v1.json", FileAccess.WRITE)
    if file == null:
        _log("Save failed: " + error_string(FileAccess.get_open_error()))
        return
    file.store_string(JSON.stringify(build_snapshot()))
    file.close()
    _log("Maintenance snapshot stored locally.")
    _refresh()

func load_progress() -> void:
    if not FileAccess.file_exists("user://maintenance_bay_v1.json"):
        _log("There is no saved maintenance snapshot.")
        return
    var file: FileAccess = FileAccess.open("user://maintenance_bay_v1.json", FileAccess.READ)
    if file == null:
        return
    var data: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(data) != TYPE_DICTIONARY or not apply_snapshot(data):
        _log("Save file rejected: incompatible or invalid maintenance state.")
