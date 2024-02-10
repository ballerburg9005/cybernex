@tool
extends AnimatableBody2D

@export var projectile : Projectile

var counter = 0
var position_history = [Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),]

var wall_hack = 0
var has_exploded = false

@export var target : Vector2
@export var speed : int = 100

var wall_hack_timer = Timer.new()
		
func _ready():
	if not projectile:
		projectile = Projectile.new()
	$CollisionShape2D.shape.radius = projectile.bullet_radius
	$CollisionShape2D.shape.height = projectile.bullet_height
	$explosion/CollisionShape2D.shape.radius = projectile.explosion_radius
	$Sprite2D.sprite_frames = projectile.sprite_frames
	speed = projectile.speed if not speed else speed

	if projectile.harms_player:
		$influence.set_collision_mask_value(12, true)
	if projectile.harms_enemies:
		$influence.set_collision_mask_value(16, true)
	
	if wall_hack > 0:
		for i in [5,7,20,22]:
			$influence.set_collision_mask_value(i, false)
		$CollisionShape2D.set_deferred("disabled", true)
		var wall_hack_timer = Timer.new()
		wall_hack_timer.one_shot = true
		wall_hack_timer.timeout.connect(wall_hack_timer_update)
		add_child(wall_hack_timer)
		wall_hack_timer.start(wall_hack*8.0/speed)
	
	if not target and not Engine.is_editor_hint():
		call_deferred("explode")

func wall_hack_timer_update():
	for i in [5,7,20,22]:
			$influence.set_collision_mask_value(i, true)
	$CollisionShape2D.set_deferred("disabled", false)

func explode():
	if $Sprite2D.sprite_frames and $Sprite2D.sprite_frames.has_animation("explode"):
		### TODO harm player,
		$Sprite2D.play("explode")
		var direct_hits = []
		for e in $influence.get_overlapping_bodies():
			if "health" in e.get_parent():
				e.get_parent().health -= projectile.damage
				direct_hits.append(e.get_parent())
		if projectile.explosion_radius > 1:
			for e in $explosion.get_overlapping_bodies():
				if "health" in e.get_parent() and not e.get_parent() in direct_hits:
					(e.get_parent().global_position - $explosion.global_position).length()
					var dist = (e.global_position - $explosion.global_position).length()
					e.get_parent().health -= projectile.damage * 1/(dist/20.0 if abs(dist/20.0)>1 else 1)
	else:
		get_parent().remove_child(self)
		queue_free()
	
	has_exploded = true


func _process(delta):
	if not Engine.is_editor_hint():
		if not has_exploded:
			# when stuck
			counter = (counter+1)%9999999999
			position_history[int((counter%10))] = position
			var sum = 0
			for p in range(0, position_history.size()):
				sum += (position - position_history[p]).length()
			if sum < 1 or abs(position.x) > 10000 or abs(position.y) > 10000:
				explode()
		
			move_and_collide((target - global_position).normalized() * speed * delta)


func _on_influence_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	explode()


func _on_sprite_2d_animation_finished():
	if has_exploded:
		get_parent().remove_child(self)
		queue_free()
