@tool
extends Resource
class_name InvItem

@export var name: String = ""
## Optional stable identity; otherwise the resource_path defines the stack type.
## Unnamed runtime-only Resources stack only with the same instance.
@export var item_id: String = ""
@export var short_name: String = ""
@export var texture: Texture2D
@export var damage: float = 0.0
@export var combos: Array[InvCombo] = []

const IS_NOT = 1
const IS_TOOL = 2
const IS_WEAPON = 4
const IS_FOOD = 8
const IS_JUNK = 16
const IS_AUGMENTATION = 32

@export_flags("!item", "tool", "weapon", "food", "junk", "augmentation") var type: int = 0
## Slot ID strings are displayed in the Godot mannequin scene.
## Weapons can occupy both hands; augmentations can target their own sockets.
@export var equipment_slots: PackedStringArray = PackedStringArray()
## Salvaged circuit parts resolve to an actual authored Godot electronic model.
@export var circuit_part: CircuitPart
@export_multiline var description: String = ""
