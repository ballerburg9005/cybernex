extends CharacterBody2D

@export var myname = "player"
@export var health = 100.0

const is_player = true

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const SCALE = 3.0

var counter = 0
var last_health
var mouse_target = null

var activatables = []
var combinables = []

@export var inventory : Inv
@export var quickinventory : Inv
@export var equipment: EquipmentLoadout

func _ready():
    last_health = health
    # The .tres entries are starter templates, not shared global runtime state.
    # A second spawned player or reloaded level must not inherit first player's
    # consumed supplies, quickbar bindings or installed gear.
    if inventory != null:
        inventory = inventory.duplicate(true)
    if quickinventory != null:
        quickinventory = quickinventory.duplicate(true)
    if equipment != null:
        equipment = equipment.duplicate(true)
    if equipment == null:
        equipment = EquipmentLoadout.new()
    if inventory != null:
        inventory.normalize()
    
    get_node("/root/main/HUD/FullInventory").visible = false
    for e in [inventory, quickinventory]:
        for i in range(0, e.items.size()):
            if not e.items[i]:
                e.items[i] = InvSlot.new()
    $PlayerReach/Sprite2D.visible = false
    pass
    
## UI inventory operations use native Godot Control drag/drop. No cloned
## physics bodies are created in CanvasLayer or Camera2D spaces.

func use_item_on_item(from_inv: Inv, to_inv: Inv, fidx: int, tidx: int) -> bool:
    var result: Dictionary = InventoryOperations.move_or_combine(from_inv, fidx, to_inv, tidx)
    get_node("/root/main").p(str(result.get("message", "Nothing happened")))
    return bool(result.get("ok", false))


func add_inventory_item(itemslot: InvSlot, start: int = -1, inv: Inv = null) -> bool:
    var actual: Inv = inventory if inv == null else inv
    if actual == null or itemslot == null:
        return false
    return actual.add_stack(itemslot, start)


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("action_1"):
        for obj in activatables.duplicate():
            if is_instance_valid(obj):
                obj.activate(self)
    if event.is_action_pressed("action_inventory"):
        var panel: Control = get_node("/root/main/HUD/FullInventory")
        panel.visible = not panel.visible


func _physics_process(delta):
    counter = (counter+1)%9999999999

    # Handle jump.
    #if Input.is_action_just_pressed("action_1") and is_on_floor():
    #	velocity.y = JUMP_VELOCITY

    # keyboard
    var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = direction * SPEED
    if direction.x + direction.y > 0.1:
        mouse_target = null

    # mouse
    if mouse_target:
        velocity += (SCALE*position).direction_to(mouse_target) * SPEED
        if (SCALE*position).distance_to(mouse_target) < 10:
            mouse_target = null

    velocity = velocity.normalized()*SPEED

    if velocity.x < 0:
        $Sprite.flip_h = true
    elif velocity.x > 0:
        $Sprite.flip_h = false

    if abs(velocity.x) + abs(velocity.y) < 0.1:
        $Sprite.play("default")
    else:
        $Sprite.play("run")
        
    # update stuff less frequently
    if counter%10 == 0:
        var mr = min(health,100)/100.0
        $Sprite.set_modulate(Color(1,mr,mr,1))
    if counter%10 == 0:
        if health < last_health:
            var mr = min(last_health - health,20)/20.0
            mr *= 100.0/(health if health > 0 else 1) if health-50 < 0 else 1
            mr = 1 if mr > 1 else mr
            $HurtBox/HurtShader.material.set_shader_parameter("alpha", mr)
            last_health -= 1
        else:
            $HurtBox/HurtShader.material.set_shader_parameter("alpha", 0.0)

    move_and_slide()
    
func p(s):
    get_node("/root/main").p(s)
