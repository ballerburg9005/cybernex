extends Node2D

@export var myname = "door"

var mytype = "door"

var animatable
var last_animation

var callers = []

signal finished_playing


func _ready():
	animatable = $StaticBody2D/AnimationPlayer
	last_animation = animatable.assigned_animation

func set_callers_playing(state):
	for caller in callers:
		if "animation_playing" in caller:
			if state == false and caller.animation_playing.has(self):
				caller.animation_playing.erase(self)
			elif state == true and not caller.animation_playing.has(self):
				caller.animation_playing.append(self)


func _on_animation_player_animation_finished(anim_name):
	set_callers_playing(false)
	finished_playing.emit()


func _on_do_toggle(object, instant = false, state = null):
	if (state != null and state) or state == null and last_animation in ["activate", "on"]:
		_on_do_deactivate(object, instant)
	else:
		_on_do_activate(object, instant)


func _on_do_activate(object, instant = false):
	get_node("/root/main").p(myname+" activated.")
	var animated = false

	if animatable and animatable.has_animation("activate") and not instant:
		animated = true
		animatable.play("activate")
	else:
		animatable.play("on")
		
	if not callers.has(object):
		callers.append(object)
	set_callers_playing(animated)
	last_animation = "on"
	

func _on_do_deactivate(object, instant = false):
	get_node("/root/main").p(myname+" deactivated.")
	var animated = false
	if animatable:
		if animatable.has_animation("deactivate") and not instant:
			animatable.play("deactivate")
			animated = true
		else:
			if animatable.has_animation("activate")  and not instant:
				animatable.play_backwards("activate")
				animated = true
			else:
				animatable.play("off")

	set_callers_playing(animated)
	last_animation = "off"
