extends Resource

class_name Inv

@export var items : Array[InvSlot]

func _init(slots = 9):
	if not items or items.size() == 0:
		items = []
		for i in range(0,slots):
			items.append(InvSlot.new())


func count(item = preload("res://items/blank.tres")):
	var num = 0
	for e in items:
		if e.item == item:
			num += 1
	return num


func has(item):
	for e in items:
		if e.item == item:
			return true
	return false


func size():
	return items.size() 


func find(item):
	for i in range(0, items.size()):
		if items[i].item == item:
			return i
	return -1
