extends Resource

class_name Component

@export var name: String = ""
@export var short_name: String = ""
@export var texture: Texture2D 

@export var value: int = 100

@export var no_rotate = false
@export var no_drag   = true

@export var is_input  = false
@export var is_output = false
@export var is_ground = false

@export var pnp: bool = true

@export var connections: Dictionary = {"left": [],"top": [], "right": [], "bottom": []}

