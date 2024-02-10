extends Resource

class_name Inv

@export var items : Array[InvSlot]

func has(item):
	for e in items:
		if e.item == item:
			return true
	return false
	
func find(item):
	for i in range(0, items.size()):
		if items[i].item == item:
			return i
	return -1
