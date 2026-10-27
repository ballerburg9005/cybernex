extends RefCounted
class_name CircuitCompiler

## Compile a tile board into a terminal-level netlist. PhysicsServer and textures
## are intentionally absent here. All coordinates are integer board coordinates.
static func compile(board: CircuitBoard) -> Dictionary:
    var errors: Array[String] = []
    var parent: Dictionary = {}
    var endpoints: Dictionary = {}
    var elements: Array[Dictionary] = []
    var ground_keys: Array[String] = []
    for i in range(board.placements.size()):
        var placement: CircuitPlacement = board.placements[i]
        if placement == null or placement.part == null:
            errors.append("Part %d is empty." % i)
            continue
        if not board.can_place(placement, i):
            errors.append("Part %d overlaps or exceeds board boundaries." % i)
            continue
        var part: CircuitPart = placement.part
        var pin_keys: Dictionary = {}
        var group_keys: Dictionary = {}
        for j in range(part.pins.size()):
            var pin: CircuitPin = part.pins[j]
            if pin == null:
                errors.append("Part %d has a null pin." % i)
                continue
            var transformed: Dictionary = placement.rotated_pin(pin)
            var at: Vector2i = transformed["cell"]
            var edge: int = transformed["side"]
            var name: String = "%d:%d" % [i, j]
            if pin_keys.has(pin.name):
                errors.append("Part %d has a duplicate pin label %s." % [i, pin.name])
            pin_keys[pin.name] = name
            parent[name] = name
            var edge_key: String = "%d,%d,%d" % [at.x, at.y, edge]
            if not endpoints.has(edge_key):
                endpoints[edge_key] = []
            endpoints[edge_key].append(name)
            if part.model == "wire":
                var group_key: String = "%d:hub:%d" % [i, pin.wire_group]
                parent[group_key] = group_key
                group_keys[j] = group_key
        if part.model == "ground" and not placement.failed_open:
            for pin_key in pin_keys.values():
                ground_keys.append(pin_key)
        if part.model == "wire":
            if not placement.failed_open:
                for j in group_keys:
                    var wire_pin: CircuitPin = part.pins[j]
                    elements.append({
                        "id": "%d:%d" % [i, j], "part_index": i,
                        "kind": "resistor", "from_key": pin_keys[wire_pin.name],
                        "to_key": group_keys[j], "ohms": maxf(part.value * 0.5 + placement.joint_resistance_ohms * 0.5, 0.0001)
                    })
        elif part.model != "ground":
            elements.append({
                "id": "%d:%s" % [i, part.part_id],
                "part_index": i, "kind": part.model, "pin_keys": pin_keys,
                "part": part, "failed": placement.failed_open
            })
    # Adjacent footprints connect only at matching physical edges.
    # In particular, a crossover's independent wire groups never short.
    for edge_key in endpoints:
        var values: PackedStringArray = edge_key.split(",")
        var x: int = int(values[0])
        var y: int = int(values[1])
        var side: int = int(values[2])
        var dx: int = [-1, 0, 1, 0][side]
        var dy: int = [0, -1, 0, 1][side]
        var opposite: String = "%d,%d,%d" % [x + dx, y + dy, (side + 2) % 4]
        if endpoints.has(opposite):
            for a in endpoints[edge_key]:
                for b in endpoints[opposite]:
                    _union(parent, a, b)
    var roots: Dictionary = {}
    for ground_key in ground_keys:
        roots[_find(parent, ground_key)] = 0
    var next_index: int = 1
    for key in parent:
        var root: String = _find(parent, key)
        if not roots.has(root):
            roots[root] = next_index
            next_index += 1
    var resolved: Array[Dictionary] = []
    for element in elements:
        var copy: Dictionary = element.duplicate()
        if copy.has("from_key"):
            copy["a"] = roots[_find(parent, copy["from_key"])]
            copy["b"] = roots[_find(parent, copy["to_key"])]
            copy.erase("from_key")
            copy.erase("to_key")
        else:
            var pins: Dictionary = {}
            for pin_name in copy["pin_keys"]:
                pins[pin_name] = roots[_find(parent, copy["pin_keys"][pin_name])]
            copy["pins"] = pins
            copy.erase("pin_keys")
        resolved.append(copy)
    if ground_keys.is_empty():
        errors.append("No reference ground; voltages are not defined.")
    return {"elements": resolved, "node_count": next_index, "errors": errors}

static func _find(parent: Dictionary, key: String) -> String:
    if parent[key] != key:
        parent[key] = _find(parent, parent[key])
    return parent[key]

static func _union(parent: Dictionary, a: String, b: String) -> void:
    var ra: String = _find(parent, a)
    var rb: String = _find(parent, b)
    if ra != rb:
        parent[rb] = ra
