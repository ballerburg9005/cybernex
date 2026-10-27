extends Node
class_name StationAdversary

## Finite sabotage capabilities: no deus-ex-machina actions. Every attack
## must have a powered actuator and spends its own resource budget.
signal sabotage(message: String)
@export var station: StationNetwork
@export var atmosphere: StationAtmosphere
@export var gas_injector_device_id: String = "security_gas_valve"
@export var initial_action_budget: int = 2
@export_range(1.0, 600.0, 1.0) var minimum_interval_seconds: float = 25.0
@export_range(0.001, 0.5, 0.001) var attack_injection_rate: float = 0.12
var actions_remaining: int = 0
var cooldown: float = 0.0
var player_detected: bool = false

func _ready() -> void:
    actions_remaining = initial_action_budget

func step(seconds: float) -> void:
    cooldown = maxf(0.0, cooldown - maxf(seconds, 0.0))
    if not player_detected or cooldown > 0.0 or actions_remaining <= 0:
        return
    if station == null or atmosphere == null:
        return
    if not bool(station.device_online.get(gas_injector_device_id, false)):
        return
    actions_remaining -= 1
    cooldown = minimum_interval_seconds
    atmosphere.gas_injection_per_second = attack_injection_rate
    sabotage.emit("Security AI opened a powered inert-gas valve. Restore ventilation or isolate the valve.")

func isolate_gas() -> void:
    if atmosphere != null:
        atmosphere.gas_injection_per_second = 0.0

func snapshot() -> Dictionary:
    return {"budget": actions_remaining, "cooldown": cooldown, "detected": player_detected}

func restore(data: Dictionary) -> void:
    actions_remaining = maxi(0, int(data.get("budget", initial_action_budget)))
    cooldown = maxf(0.0, float(data.get("cooldown", 0.0)))
    player_detected = bool(data.get("detected", false))
