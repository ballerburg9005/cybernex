extends Resource
class_name InvCombo

## Preserves existing Inspector-authored 'with', 'yields', 'amount',
## and eats_* fields. Added optional per-ingredient quantities.
@export var with: InvItem
@export var yields: InvItem
@export_range(0, 999, 1) var amount: int = 1
@export var eats_source: bool = true
@export var eats_target: bool = true
@export_range(1, 999, 1) var source_amount: int = 1
@export_range(1, 999, 1) var target_amount: int = 1

func _init(i: InvItem = null, a: int = 1, es: bool = true, et: bool = true) -> void:
    yields = i
    amount = a
    eats_source = es
    eats_target = et
