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
            if not spawn_item(InvSlot.new(preload("res://items/wires.tres"), howmany)):
                return [false, false]
            howoften -= 1
            if howoften == 0:
                broken = false
            return [true, false]
    # success, consumed, error
    return [false, false]


func spawn_item(itemslot: InvSlot) -> bool:
    # Salvage has to come to rest on free floor. In the original code the
    # pickup body spawned partly inside the wall and was pushed downward via
    # move_and_collide on a StaticBody2D; after the timer expired it stayed
    # embedded, unable to be reached or picked up.
    var game: Node = get_node_or_null("/root/main")
    if game == null or itemslot == null or not itemslot.occupied():
        return false
    var landing: Dictionary = game._safe_drop_position(global_position + Vector2(0, 20))
    if not bool(landing.get("ok", false)):
        game.p("Nothing falls free of the wall.")
        return false
    var pickup: WorldItemPickup = preload("res://items/item_world.tscn").instantiate()
    pickup.itemslot = itemslot
    pickup.name = "spawned_" + itemslot.item.short_name
    get_parent().add_child(pickup)
    pickup.global_position = landing["point"]
    myitem = pickup
    return true
