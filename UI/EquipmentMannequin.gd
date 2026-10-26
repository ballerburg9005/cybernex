extends PanelContainer
class_name EquipmentMannequin

signal feedback(message: String)
var backpack: Inv
var loadout: EquipmentLoadout
var runtime: EquipmentRuntime
var _reported_energy: float = -1.0
var sockets: Array[EquipmentSlot] = []

func setup(inv: Inv, equipment: EquipmentLoadout) -> void:
    if backpack != null and backpack.changed.is_connected(_on_backpack_changed):
        backpack.changed.disconnect(_on_backpack_changed)
    if loadout != null and loadout.changed.is_connected(_update_sockets):
        loadout.changed.disconnect(_update_sockets)
    backpack = inv
    loadout = equipment
    if loadout == null or backpack == null:
        return
    if sockets.is_empty():
        for child in $Frame/Layout/Canvas.get_children():
            if child is EquipmentSlot:
                sockets.append(child)
    for socket in sockets:
        socket.setup(loadout, backpack, self)
    backpack.changed.connect(_on_backpack_changed)
    loadout.changed.connect(_update_sockets)
    loadout.reconcile(backpack)
    _update_sockets()

func set_runtime(next: EquipmentRuntime) -> void:
    runtime = next
    _reported_energy = -1.0
    _update_sockets()

func _process(_delta: float) -> void:
    if runtime == null or not is_node_ready():
        return
    if absf(_reported_energy - runtime.charge_wh) > 0.04:
        _update_sockets()

func _on_backpack_changed() -> void:
    if loadout != null:
        loadout.reconcile(backpack)
    _update_sockets()

func _update_sockets() -> void:
    for socket in sockets:
        socket.update_display()
    if is_node_ready() and loadout != null:
        var guns: int = 0
        var augmentations: int = 0
        for key in EquipmentLoadout.SOCKETS:
            if loadout.item_at(key) != null:
                if key.begins_with("weapon_"):
                    guns += 1
                else:
                    augmentations += 1
        var reading: String = ""
        if runtime != null:
            _reported_energy = runtime.charge_wh
            reading = "  |  SUIT %.2f/%.0f Wh" % [runtime.charge_wh, runtime.capacity_wh]
        $Frame/Layout/LoadoutStatus.text = ("%d / 8 SOCKETS    |    %d WEAPONS    |    %d AUGMENTATIONS" % [loadout.occupied_sockets(), guns, augmentations]) + reading

func message(value: String) -> void:
    $Frame/Layout/Hint.text = value
    feedback.emit(value)
