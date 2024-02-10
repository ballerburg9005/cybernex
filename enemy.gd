extends CharacterBody2D

@export var myname = "bot"
@export var health = 100.0

@export var drops : InvSlot

@export var stationary = false

const SCALE = 3
const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var movement_target = null

var movement_timer = Timer.new()
var movement_timer2 = Timer.new()
var movement_timer_ok = true

var projectile_timer = Timer.new()
var projectile_timer_ok = true


var position_history = [Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),Vector2(0,0),]
var counter = 0

var attack_targets = []
var attack_pursue_targets = []
var can_shoot_target = false

var starting_health
var is_dying = false
var dropped_item
var do_drop = false
var do_drop_timer = Timer.new()
func _ready():
	if not drops:
		var randarr = [preload("res://items/big_wire.tres"), preload("res://items/wires.tres"), preload("res://items/junk.tres")]
		drops = InvSlot.new(randarr[randi()%randarr.size()],randi()%3)
	do_drop_timer.one_shot = true
	do_drop_timer.timeout.connect(do_drop_timer_update)
	add_child(do_drop_timer)
	
	starting_health = health
	
	$CPUParticles2D.emitting = false
	movement_timer.one_shot = true
	movement_timer.timeout.connect(movement_timer_update)
	movement_timer2.one_shot = true
	movement_timer2.timeout.connect(movement_timer2_update)
	projectile_timer.one_shot = true
	projectile_timer.timeout.connect(projectile_timer_update)
	
	add_child(movement_timer)
	add_child(movement_timer2)
	add_child(projectile_timer)
	movement_timer2.start(randi()%10)


func projectile_timer_update():
	projectile_timer_ok = true


func movement_timer2_update():
	movement_timer_ok = false
	movement_timer.start(randi()%2+1)


func movement_timer_update():
	movement_timer_ok = true


# the particle effect for the levitation
func set_particles(direction):
	if direction.length() >= 0.2:
		$CPUParticles2D.emitting = true
		$CPUParticles2D.gravity = -direction*10
		$CPUParticles2D.lifetime = 0.2 # + direction.y #*(0.002 if direction.y < 0 else 0.0025)
	else:
		$CPUParticles2D.emitting = false


func spawn_projectile(target):
	var do_wall_hack = 0
	$hitbox/outside_wall.target_position = -$hitbox.position
	$hitbox/outside_wall.force_raycast_update()
	if $hitbox/outside_wall.get_collider():
		if $hitbox.global_position.y < target.y:
			$hitbox/outside_wall.target_position = target - $hitbox.global_position
			$hitbox/outside_wall.force_raycast_update()
			do_wall_hack = ($hitbox/outside_wall.get_collision_point() - $hitbox.global_position).length()
		else:
			return false

	var projectile = preload("res://projectiles/projectile.tscn").instantiate()
	projectile.global_position = $hitbox.global_position/SCALE
	projectile.target = target
	projectile.speed = 1000
	projectile.wall_hack = do_wall_hack
	projectile.name = "Projectile"
	projectile.projectile = preload("res://projectiles/beam.tres")
	projectile.projectile.damage = 3
	projectile.projectile.harms_player = true
		
	get_node("/root/main/World").add_child(projectile)

	return true

func _physics_process(delta):

	if health <= 0:
		is_dying = true
		$Sprite.set_modulate(Color(1,1,1,1))
		$Sprite.play("death")
		if dropped_item and do_drop:
			dropped_item.move_and_collide(Vector2(0,200) * delta)
		return true
	counter = (counter+1)%9999999999
	if counter%10 == 0:
		# set health color
		var mr = min(health,starting_health)/starting_health
		$Sprite.set_modulate(Color(1,mr,mr,1))
		
		# detect when stuck and stop moving
		position_history[int((counter%100)*0.1)] = position
		var sum = 0
		for p in range(0, position_history.size()):
			sum += (position - position_history[p]).length()
		if sum < 1:
			movement_target = null
		
	if movement_target == null or (movement_target - global_position).length() < 10:
		var found_passage = false
		var target_positions = []
		for i in range(0,3):
			$RayCastPath.target_position = Vector2((randi()%200)-100,(randi()%200)-100)
			$RayCastPath.force_raycast_update()
			if not $RayCastPath.get_collider():
				found_passage = true
				target_positions += [$RayCastPath.target_position]
			elif($RayCastPath.get_collision_point() - $RayCastPath.global_position).length() > 100:
				found_passage = true
				target_positions += [$RayCastPath.get_collision_point() - $RayCastPath.global_position]
				break
		if target_positions.size() > 0:
			target_positions.sort_custom(func(a,b): return a.length() < b.length())
			movement_target = global_position + target_positions[0]
		if found_passage == false and movement_timer_ok:
			movement_timer_ok = false
			movement_timer.start(3)

	if attack_targets.size() > 0:
		if attack_pursue_targets.has(attack_targets[0]):
			movement_target = attack_targets[0].global_position - (attack_targets[0].global_position-global_position).normalized()*100
		$attack/RayCast2D.target_position = (attack_targets[0].global_position - global_position)/SCALE
		$attack/RayCast2D.force_raycast_update()
		if $attack/RayCast2D.get_collider():
			can_shoot_target = false
		else:
			can_shoot_target = true
		
		if attack_targets[0].global_position.x - global_position.x > 0:
			$Sprite.flip_h = false
		else:
			$Sprite.flip_h = true
	else:
		can_shoot_target = false
		
		if velocity.x < 0.1:
			$Sprite.flip_h = true
		elif velocity.x > 0.1:
			$Sprite.flip_h = false

	if can_shoot_target and projectile_timer_ok:
		projectile_timer_ok = false
		projectile_timer.start(0.1+randf()*1)
		spawn_projectile(attack_targets[0].global_position + (attack_targets[0].global_position - $hitbox.global_position)*1000)

	if movement_target and (movement_target - global_position).length() < 10:
			movement_target = null
			
	if not movement_target == null and movement_timer_ok and not stationary:
		velocity = (movement_target - global_position).normalized() * SPEED/3
	else:
		velocity = Vector2(0,0)

	if abs(velocity.x) + abs(velocity.y) < 0.1:
		$Sprite.play("default")
		set_particles(Vector2(0,0))
	else:
		$Sprite.play("run")
		set_particles(velocity)
		
	move_and_slide()


func _on_attack_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	for e in [attack_targets, attack_pursue_targets]:
		if body.has_node("hitbox"):
			if not e.has(body.get_node("hitbox")):
				e.append(body.get_node("hitbox"))
		else:
			if not e.has(body):
				e.append(body)


func _on_attack_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	if body.has_node("hitbox"):
		attack_pursue_targets.erase(body.get_node("hitbox"))
	else:
		attack_pursue_targets.erase(body)

func _on_range_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	if body.has_node("hitbox"):
		attack_targets.erase(body.get_node("hitbox"))
	else:
		attack_targets.erase(body)


func _on_sprite_animation_finished():
	if is_dying:
		if drops:
			dropped_item = preload("res://items/item_world.tscn").instantiate()
			dropped_item.itemslot = drops
			dropped_item.name = "spawned_"+drops.item.short_name
			dropped_item.global_position = $hitbox.global_position/SCALE
			get_node("/root/main/World").add_child(dropped_item)
			do_drop = true
			do_drop_timer.start(0.2)
		else:
			get_parent().remove_child(self)
			queue_free()


func do_drop_timer_update():
	do_drop = false
	get_parent().remove_child(self)
	queue_free()
