extends Resource

class_name Component

@export var name: String = ""
@export var short_name: String = ""
@export var texture: Texture2D 

@export var value: int = 100

@export var is_input = false
@export var is_output = false
@export var is_ground = false

@export var pnp: bool = true

@export var connections: Dictionary = {"left": -1,"top": -1, "right": -1, "bottom": -1}
