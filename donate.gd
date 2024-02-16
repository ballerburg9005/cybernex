extends Control

var timer0 := Timer.new()

func _ready():
	timer0.one_shot = true

	timer0.timeout.connect(_timer0)

	add_child(timer0)

	timer0.start(5)

func _timer0():
	get_tree().quit()
