extends StaticBody2D

@export var myname = "terminal"

var mytype = "terminal"


@export var access_granted = false
@export var disabled = false
@export var puzzle_type = "none"
@export_range(0, 20) var puzzle_difficulty = 0

var animation_playing = []
var is_activated = false

signal do_activate
signal do_deactivate


func _ready():
	call_deferred("_started")


# reset animation based on access
func _started():
	if access_granted:
		play_activate(true)
	else:
		play_deactivate(true)


# start puzzle
func activate(caller):
	if disabled:
		get_node("/root/main").p("Terminal is not functional.")
	elif animation_playing.size() == 0:
		if access_granted:
			if not is_activated:
				play_activate()
			else:
				play_deactivate()
		elif puzzle_type == "none":
			access_granted = true
			play_activate()
		else:
			get_node("/root/main").p("Terminal needs to be fixed!")


func play_activate(instant = false):
	is_activated = true
	do_activate.emit(self, instant)


func play_deactivate(instant = false):
	is_activated = false
	do_deactivate.emit(self, instant)


func _on_influence_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	if not disabled:
		if "activatables" in body:
			body.activatables.append(self)
		if $AnimatedSprite2D:
			$AnimatedSprite2D.play("on")


func _on_influence_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	if "activatables" in body and body.activatables.has(self):
		body.activatables.erase(self)
	if $AnimatedSprite2D:
		$AnimatedSprite2D.play("off")
