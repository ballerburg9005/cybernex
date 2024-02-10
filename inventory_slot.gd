extends Resource

class_name InvSlot

@export var item: InvItem = preload("res://items/blank.tres")
@export var count: int = 1

func _init(i = preload("res://items/blank.tres"), c = 1):
	item = i
	count = c
	
