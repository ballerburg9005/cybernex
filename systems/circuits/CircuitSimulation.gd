extends RefCounted
class_name CircuitSimulation

## DC modified nodal conductance solver with fixed-point nonlinear devices.
## Nominal values are intentionally simplified but grounded in voltage/current laws.
## No game scene nodes, drawing, physics, or global singletons in this class.
var temperatures_c: Dictionary = {}
var last_voltages: Array[float] = []
var stable_seconds: float = 0.0
## One stored voltage (C) or current (L) per physical part placement.
var reactive_history: Dictionary = {}
var ambient_c: float = 23.0

func step(board: CircuitBoard, delta_seconds: float = 0.05) -> Dictionary:
    var netlist: Dictionary = CircuitCompiler.compile(board)
    var errors: Array = netlist["errors"].duplicate()
    if not errors.is_empty():
        stable_seconds = 0.0
        return {"errors": errors, "solved": false, "voltages": [], "currents": {}, "watts": {}}
    var count: int = netlist["node_count"]
    var voltages: Array[float] = []
    for n in range(count):
        voltages.append(last_voltages[n] if n < last_voltages.size() else 0.0)
    var elements: Array[Dictionary] = netlist["elements"]
    var converged := false
    for iteration in range(40):
        var matrix: Array = []
        var rhs: Array[float] = []
        for i in range(count - 1):
            var row: Array[float] = []
            for j in range(count - 1):
                row.append(1e-9 if i == j else 0.0)
            matrix.append(row)
            rhs.append(0.0)
        for element in elements:
            if element.get("failed", false):
                continue
            var kind: String = element["kind"]
            if kind == "resistor" and element.has("a"):
                _stamp(matrix, rhs, element["a"], element["b"], 1.0 / maxf(element["ohms"], 0.00001))
                continue
            var pins: Dictionary = element["pins"]
            var part: CircuitPart = element["part"]
            match kind:
                "resistor", "load":
                    _stamp(matrix, rhs, _pin(pins, "A"), _pin(pins, "B"), 1.0 / maxf(part.value, 0.00001))
                "capacitor", "inductor":
                    var a: int = _pin(pins, "A")
                    var b: int = _pin(pins, "B")
                    var prev: float = float(reactive_history.get(element["id"], 0.0))
                    var series_r: float = maxf(part.secondary_value, 0.000001)
                    var reactance: float = 0.0
                    if kind == "capacitor":
                        reactance = maxf(delta_seconds, 0.000001) / maxf(part.value, 0.000000001)
                    else:
                        reactance = maxf(part.value, 0.000000001) / maxf(delta_seconds, 0.000001)
                    var g: float = 1.0 / (series_r + reactance)
                    _stamp(matrix, rhs, a, b, g)
                    if kind == "capacitor":
                        _inject(rhs, a, b, g * prev)
                    else:
                        _inject(rhs, a, b, -g * reactance * prev)
                "source":
                    var p: int = _pin(pins, "P")
                    var m: int = _pin(pins, "N")
                    var conductance: float = 1.0 / maxf(part.secondary_value, 0.001)
                    _stamp(matrix, rhs, p, m, conductance)
                    _inject(rhs, p, m, part.value * conductance)
                "diode":
                    _diode(matrix, rhs, _pin(pins, "A"), _pin(pins, "K"), voltages, part.secondary_value)
                "npn", "pnp":
                    var b: int = _pin(pins, "B")
                    var e: int = _pin(pins, "E")
                    var c: int = _pin(pins, "C")
                    var sign: float = 1.0 if kind == "npn" else -1.0
                    var forward: float = sign * (voltages[b] - voltages[e])
                    if kind == "npn":
                        _diode(matrix, rhs, b, e, voltages, maxf(part.secondary_value, 0.55))
                    else:
                        _diode(matrix, rhs, e, b, voltages, maxf(part.secondary_value, 0.55))
                    var base_current: float = maxf((forward - maxf(part.secondary_value, 0.55)) / 100.0, 0.0)
                    var ce_voltage: float = absf(voltages[c] - voltages[e])
                    var limit: float = part.gain * base_current / maxf(ce_voltage, 0.2)
                    var ce_conductance: float = clampf(limit, 1e-9, 1.0 / maxf(part.value, 0.05))
                    _stamp(matrix, rhs, c, e, ce_conductance)
                "nmos", "pmos":
                    var g: int = _pin(pins, "G")
                    var d: int = _pin(pins, "D")
                    var s: int = _pin(pins, "S")
                    var direction: float = 1.0 if kind == "nmos" else -1.0
                    var overdrive: float = direction * (voltages[g] - voltages[s]) - part.secondary_value
                    var factor: float = clampf(overdrive, 0.0, 1.0)
                    var gds: float = 1e-9 + factor / maxf(part.value, 0.01)
                    _stamp(matrix, rhs, d, s, gds)
        var solution: Array[float] = _solve(matrix, rhs)
        if solution.is_empty() and count > 1:
            errors.append("Electrical matrix is singular.")
            break
        var maximum_change: float = 0.0
        for i in range(1, count):
            var old: float = voltages[i]
            voltages[i] = 0.5 * old + 0.5 * solution[i - 1]
            maximum_change = maxf(maximum_change, absf(old - voltages[i]))
        if maximum_change < 0.00001:
            converged = true
            break
    last_voltages = voltages
    if not converged:
        errors.append("Nonlinear solution did not converge; inspect shorts or oscillating semiconductors.")
    var currents: Dictionary = {}
    var watts: Dictionary = {}
    var load_voltages: Dictionary = {}
    for element in elements:
        var index: int = element["part_index"]
        var kind: String = element["kind"]
        var current: float = 0.0
        var heat: float = 0.0
        if not element.get("failed", false):
            var a: int = 0
            var b: int = 0
            var effective_r: float = 1.0
            if element.has("a"):
                a = element["a"]
                b = element["b"]
                effective_r = element["ohms"]
                current = (voltages[a] - voltages[b]) / effective_r
                heat = current * current * effective_r
            else:
                var pins: Dictionary = element["pins"]
                var part: CircuitPart = element["part"]
                match kind:
                    "resistor", "load":
                        a = _pin(pins, "A")
                        b = _pin(pins, "B")
                        effective_r = maxf(part.value, 0.00001)
                        current = (voltages[a] - voltages[b]) / effective_r
                        heat = current * current * effective_r
                    "capacitor", "inductor":
                        a = _pin(pins, "A")
                        b = _pin(pins, "B")
                        var prev: float = float(reactive_history.get(element["id"], 0.0))
                        var series_r: float = maxf(part.secondary_value, 0.000001)
                        var reactance: float = 0.0
                        if kind == "capacitor":
                            reactance = maxf(delta_seconds, 0.000001) / maxf(part.value, 0.000000001)
                            current = (voltages[a] - voltages[b] - prev) / (series_r + reactance)
                            reactive_history[element["id"]] = prev + reactance * current
                        else:
                            reactance = maxf(part.value, 0.000000001) / maxf(delta_seconds, 0.000001)
                            current = (voltages[a] - voltages[b] + reactance * prev) / (series_r + reactance)
                            reactive_history[element["id"]] = current
                        heat = current * current * series_r
                    "source":
                        a = _pin(pins, "P")
                        b = _pin(pins, "N")
                        effective_r = maxf(part.secondary_value, 0.001)
                        current = (part.value - (voltages[a] - voltages[b])) / effective_r
                        heat = current * current * effective_r
                    "diode":
                        a = _pin(pins, "A")
                        b = _pin(pins, "K")
                        current = maxf((voltages[a] - voltages[b] - part.secondary_value) / 1.0, 0.0)
                        heat = current * maxf(voltages[a] - voltages[b], 0.0)
                    "nmos", "pmos":
                        a = _pin(pins, "D")
                        b = _pin(pins, "S")
                        var gate: int = _pin(pins, "G")
                        var polarity: float = 1.0 if kind == "nmos" else -1.0
                        var factor: float = clampf(polarity * (voltages[gate] - voltages[b]) - part.secondary_value, 0.0, 1.0)
                        current = (voltages[a] - voltages[b]) * (1e-9 + factor / maxf(part.value, 0.01))
                        heat = absf(current * (voltages[a] - voltages[b]))
                    "npn", "pnp":
                        a = _pin(pins, "C")
                        b = _pin(pins, "E")
                        var base: int = _pin(pins, "B")
                        var polarity: float = 1.0 if kind == "npn" else -1.0
                        var ib: float = maxf((polarity * (voltages[base] - voltages[b]) - maxf(part.secondary_value, 0.55)) / 100.0, 0.0)
                        var conductance: float = clampf(part.gain * ib / maxf(absf(voltages[a] - voltages[b]), 0.2), 1e-9, 1.0 / maxf(part.value, 0.05))
                        current = (voltages[a] - voltages[b]) * conductance
                        heat = absf(current * (voltages[a] - voltages[b])) + ib * maxf(part.secondary_value, 0.55)
                if kind == "load":
                    load_voltages[part.part_id] = voltages[a] - voltages[b]
        currents[element["id"]] = current
        watts[index] = float(watts.get(index, 0.0)) + heat
    var newly_failed: Array[int] = []
    for i in range(board.placements.size()):
        var placement: CircuitPlacement = board.placements[i]
        if placement == null or placement.part == null:
            continue
        var part: CircuitPart = placement.part
        var temp: float = float(temperatures_c.get(i, ambient_c))
        var power: float = float(watts.get(i, 0.0))
        # Cooling is computed even when the device is disconnected.
        var heat_flow: float = power - part.cooling_watts_per_kelvin * (temp - ambient_c)
        temp += heat_flow * maxf(delta_seconds, 0.0) / maxf(part.thermal_capacity, 0.001)
        temperatures_c[i] = temp
        if temp >= part.failure_temperature_c and not placement.failed_open:
            placement.failed_open = true
            newly_failed.append(i)
    var target: float = float(load_voltages.get(board.required_load_part_id, -1e30))
    var within_limits: bool = errors.is_empty() and newly_failed.is_empty() and target >= board.min_load_volts and target <= board.max_load_volts
    stable_seconds = stable_seconds + maxf(delta_seconds, 0.0) if within_limits else 0.0
    return {
        "errors": errors, "solved": within_limits and stable_seconds >= board.minimum_hold_seconds,
        "voltages": voltages, "currents": currents, "watts": watts,
        "temperatures_c": temperatures_c.duplicate(), "loads": load_voltages,
        "hold_seconds": stable_seconds, "converged": converged,
        "newly_failed": newly_failed
    }

static func _pin(pins: Dictionary, name: String) -> int:
    return int(pins.get(name, 0))

static func _stamp(matrix: Array, rhs: Array[float], a: int, b: int, g: float) -> void:
    if a > 0:
        matrix[a - 1][a - 1] += g
    if b > 0:
        matrix[b - 1][b - 1] += g
    if a > 0 and b > 0:
        matrix[a - 1][b - 1] -= g
        matrix[b - 1][a - 1] -= g

static func _inject(rhs: Array[float], positive: int, negative: int, current: float) -> void:
    if positive > 0:
        rhs[positive - 1] += current
    if negative > 0:
        rhs[negative - 1] -= current

static func _diode(matrix: Array, rhs: Array[float], a: int, k: int, v: Array[float], forward_drop: float) -> void:
    var on: bool = v[a] - v[k] > forward_drop
    var g: float = 1.0 if on else 1e-9
    _stamp(matrix, rhs, a, k, g)
    if on:
        _inject(rhs, a, k, g * forward_drop)

static func _solve(matrix: Array, rhs: Array[float]) -> Array[float]:
    var n: int = rhs.size()
    if n == 0:
        return []
    var m: Array = matrix.duplicate(true)
    var b: Array[float] = rhs.duplicate()
    for k in range(n):
        var pivot: int = k
        for i in range(k + 1, n):
            if absf(m[i][k]) > absf(m[pivot][k]):
                pivot = i
        if absf(m[pivot][k]) < 1e-14:
            return []
        if pivot != k:
            var row: Array = m[pivot]
            m[pivot] = m[k]
            m[k] = row
            var temp: float = b[pivot]
            b[pivot] = b[k]
            b[k] = temp
        for i in range(k + 1, n):
            var factor: float = m[i][k] / m[k][k]
            m[i][k] = 0.0
            for j in range(k + 1, n):
                m[i][j] -= factor * m[k][j]
            b[i] -= factor * b[k]
    var out: Array[float] = []
    out.resize(n)
    for i in range(n - 1, -1, -1):
        var value: float = b[i]
        for j in range(i + 1, n):
            value -= m[i][j] * out[j]
        out[i] = value / m[i][i]
    return out
