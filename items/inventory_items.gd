extends Resource

class_name InvItem

@export var name: String = ""
@export var short_name: String = ""
@export var texture: Texture2D
@export var damage: float = 0.0
@export var combos: Array[InvCombo]

const IS_NOT = 1
const IS_TOOL = 2
const IS_WEAPON = 4
const IS_FOOD = 8
const IS_JUNK  = 16

@export_flags("!item", "tool", "weapon", "food", "junk") var type = 0 

func _set(property, value):
	#print("ok")
	return true
