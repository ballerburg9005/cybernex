extends Resource
class_name InvSlot

@export var item: InvItem = preload("res://items/blank.tres")
@export_range(0, 999999, 1) var count: int = 0

func _init(i: InvItem = null, c: int = 0) -> void:
    item = i if i != null else preload("res://items/blank.tres")
    count = maxi(0, c)

func occupied() -> bool:
    return count > 0 and item != null and not (item.type & InvItem.IS_NOT)
