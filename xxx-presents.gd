extends CenterContainer

var menu_fade_out = false
var menu_fade_in = false
var text_fade_out = false

var timer0 := Timer.new()
var timer1 := Timer.new()
var timer2 := Timer.new()
var timer3 := Timer.new()

func _ready():
	timer0.one_shot = true
	timer1.one_shot = true
	timer2.one_shot = true
	timer3.one_shot = true
	
	timer0.timeout.connect(_timer0)
	timer1.timeout.connect(_timer1)
	timer2.timeout.connect(_timer2)
	timer3.timeout.connect(_timer3)

	add_child(timer0)
	add_child(timer1)
	add_child(timer2)
	add_child(timer3)

	get_node("../black2").set_modulate(Color(1,1,1,1))
	timer0.start(1)

func _timer0():
	timer1.start(3)
	menu_fade_in = true


func _timer1():
	timer2.start(1)
	get_node("../AudioStreamPlayer").playing = true
	get_node("../black2").visible = false
	
	
func _timer2():
	text_fade_out = true
	timer3.start(2)


func _timer3():
	menu_fade_out = true
	
	
func _physics_process(delta):

	if menu_fade_in == true && menu_fade_out == false:
		set_modulate(lerp(get_modulate(), Color(1,1,1,1), 0.02))
		if get_modulate().a > 0.9:
			set_modulate(Color(1,1,1,1))
			menu_fade_in = false
	if menu_fade_out == true && menu_fade_in == false:
		set_modulate(lerp(get_modulate(), Color(1,1,1,0), 0.02))
		if get_modulate().a < 0.1:
			set_modulate(Color(1,1,1,0))
			menu_fade_out = false
	if text_fade_out == true:
		$VBoxContainer2.set_modulate(lerp($VBoxContainer2.get_modulate(), Color(1,1,1,0), 0.02))
		if $VBoxContainer2.get_modulate().a < 0.1:
			$VBoxContainer2.set_modulate(Color(1,1,1,0))
			text_fade_out = false
