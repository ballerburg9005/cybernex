extends StaticBody2D

@export var myname = "object"
@export_enum("wirewall", "Mary", "Leah") var mysubtype: String
@export var howoften = 1
@export var howmany = 1
@export var broken = false

var longnames = {"wirewall": "exposed wall"}

var mytype = "object"

var myitem

var do_drop = false
var do_timer = Timer.new()
var particle_timer = Timer.new()
var particle_timer_do = true


func do_drop_false():
	do_drop = false
	
	
func particle_timer_reset():
	if has_node("CPUParticles2D"):
		get_node("CPUParticles2D").emitting = particle_timer_do if broken else false
	if particle_timer_do:
		particle_timer.start(0.3)
	else:
		particle_timer.start(1+randf()*3)

	particle_timer_do = not particle_timer_do
	
	
func _ready():
	do_timer.one_shot = true
	do_timer.timeout.connect(do_drop_false)
	add_child(do_timer)
	particle_timer.one_shot = true
	particle_timer.timeout.connect(particle_timer_reset)
	add_child(particle_timer)
	
	if has_node("CPUParticles2D"):
		get_node("CPUParticles2D").emitting = false
		particle_timer.start(1)
		
	if mysubtype in longnames:
		myname = longnames[mysubtype]
	
	if mysubtype == "wirewall":
		broken = true


func combine(itemslot):
	if mysubtype == "wirewall":
		if howoften <= 0:
			get_node("/root/main").p("No more wires to cut.")
			return [false, false, false]
		elif itemslot.item.short_name in ["sidecutters"]:
			do_drop = true
			do_timer.start(0.2)
			spawn_item(InvSlot.new(preload("res://items/wires.tres"), howmany))
			howoften -= 1
			if howoften == 0:
				broken = false
			return [true, false]
	# success, consumed, error
	return [false, false]


func spawn_item(itemslot):
	myitem = preload("res://items/item_world.tscn").instantiate()
	myitem.itemslot = itemslot
	myitem.name = "spawned_"+itemslot.item.short_name
	add_child(myitem)
	#myitem[l].z_index = 3000
	

func _process(delta):
	if myitem and do_drop:
		myitem.move_and_collide(Vector2(0,800) * delta)
 
