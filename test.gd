extends Node2D

var dragged_item = false

func _input(event):
	if dragged_item:
				$StaticBody2D.position = get_local_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragged_item = true
			pass
		elif not event.pressed:
				pass


func _on_area_2d_body_entered(body):
	print("works")
	pass # Replace with function body.
