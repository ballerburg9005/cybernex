extends Resource

class_name Projectile

@export var name: String = "beam"
@export var short_name: String = "beam"
@export var damage: int = 5
@export var sprite_frames: SpriteFrames = load("res://projectiles/beam_sprite_frames.tres")
@export var explosion_radius: int = 24
@export var bullet_radius: int = 6
@export var bullet_height: int = 12
@export var harms_player: bool = false
@export var harms_enemies: bool = false
@export var speed: int = 10


