extends Resource

class_name InvCombo

@export var with  : InvItem
@export var yields : InvItem = InvItem.new()
@export var amount : int = 1
@export var eats_source : bool = true
@export var eats_target : bool = true

func _init(i = load("res://items/junk.tres"), a = 1, es = true, et = true):
	yields = i
	amount = a
	eats_source = es
	eats_target = et
	
