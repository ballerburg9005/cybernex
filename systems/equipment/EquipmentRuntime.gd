extends RefCounted
class_name EquipmentRuntime

## Equipment consumes real stored electrical energy. The mannequin references
## physical backpack stock; it does not mint bonus items, guns, or batteries.
var capacity_wh: float = 24.0
var charge_wh: float = 16.0
var active_draw_watts: float = 0.0
var cooldown_seconds: float = 0.0

func _equipped(loadout: EquipmentLoadout, backpack: Inv) -> Array[InvItem]:
    var result: Array[InvItem] = []
    if loadout == null or backpack == null:
        return result
    # EquipmentMannequin already reconciles on inventory/loadout changes.
    # Physics-frame reads must not mutate resources or emit change signals.
    for socket in EquipmentLoadout.SOCKETS:
        var item: InvItem = loadout.item_at(socket)
        if item != null and item.equipment_slots.has(socket):
            result.append(item)
    return result

func tick(delta_seconds: float, loadout: EquipmentLoadout, backpack: Inv) -> void:
    if delta_seconds <= 0.0:
        return
    cooldown_seconds = maxf(0.0, cooldown_seconds - delta_seconds)
    active_draw_watts = 0.0
    if charge_wh <= 0.0:
        return
    for item in _equipped(loadout, backpack):
        active_draw_watts += item.powered_draw_watts
    charge_wh = maxf(0.0, charge_wh - active_draw_watts * delta_seconds / 3600.0)
    if charge_wh <= 0.0:
        active_draw_watts = 0.0

func locomotion_multiplier(loadout: EquipmentLoadout, backpack: Inv) -> float:
    if charge_wh <= 0.0:
        return 1.0
    var multiplier: float = 1.0
    for item in _equipped(loadout, backpack):
        multiplier *= item.locomotion_multiplier
    return clampf(multiplier, 0.5, 2.0)

func diagnostic_level(loadout: EquipmentLoadout, backpack: Inv) -> int:
    if charge_wh <= 0.0:
        return 0
    var level: int = 0
    for item in _equipped(loadout, backpack):
        level = maxi(level, item.diagnostic_level)
    return level

func service_reach_bonus(loadout: EquipmentLoadout, backpack: Inv) -> float:
    if charge_wh <= 0.0:
        return 0.0
    var additional: float = 0.0
    for item in _equipped(loadout, backpack):
        additional += item.service_reach_bonus
    return minf(100.0, additional)

func try_discharge(loadout: EquipmentLoadout, backpack: Inv) -> Dictionary:
    if cooldown_seconds > 0.0:
        return {"ok": false, "reason": "Coil needs time to recover."}
    if loadout == null or backpack == null:
        return {"ok": false, "reason": "No equipment."}
    var item: InvItem = loadout.item_at("weapon_primary")
    if item == null:
        item = loadout.item_at("weapon_secondary")
    if item == null or not backpack.has(item) or item.discharge_wh <= 0.0:
        return {"ok": false, "reason": "No powered tool in a weapon socket."}
    if charge_wh < item.discharge_wh:
        return {"ok": false, "reason": "Suit battery depleted."}
    charge_wh -= item.discharge_wh
    cooldown_seconds = 0.75
    return {"ok": true, "range": item.discharge_range, "item": item,
        "energy_spent_wh": item.discharge_wh}

func recharge(item: InvItem, backpack: Inv) -> bool:
    if item == null or backpack == null or item.energy_wh <= 0.0:
        return false
    if charge_wh >= capacity_wh - 0.01:
        return false
    if not backpack.remove_item(item, 1):
        return false
    charge_wh = minf(capacity_wh, charge_wh + item.energy_wh)
    return true

func snapshot() -> Dictionary:
    return {"charge_wh": charge_wh, "cooldown": cooldown_seconds}

func restore(data: Dictionary) -> bool:
    var next_charge: float = float(data.get("charge_wh", -1.0))
    var next_cooldown: float = float(data.get("cooldown", -1.0))
    if not is_finite(next_charge) or not is_finite(next_cooldown):
        return false
    if next_charge < 0.0 or next_charge > capacity_wh or next_cooldown < 0.0 or next_cooldown > 60.0:
        return false
    charge_wh = next_charge
    cooldown_seconds = next_cooldown
    return true
