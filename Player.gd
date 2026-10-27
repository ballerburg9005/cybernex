extends CharacterBody2D

@export var myname = "player"
@export var health = 100.0

const is_player = true
signal weapon_fired(hit: Node, energy_wh: float)

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
var equipment_runtime := EquipmentRuntime.new()
var unsecured_head_seconds: float = 0.0

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
        inventory.auto_group_stacks = false
        inventory.ensure_slots()
    
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
    var host: Node = get_node_or_null("/root/main")
    if host == null:
        return
    if event.is_action_pressed("action_inventory") and not event.is_echo():
        # Tab always returns to the backpack from another drawer page.
        host.toggle_inventory()
        get_viewport().set_input_as_handled()
        return
    if host.ui_captures_world_input():
        return
    if event is InputEventMouseButton and (host.is_hud_drop_region(event.position)
        or get_viewport().gui_get_drag_data() != null):
        return
    if event.is_action_pressed("action_1"):
        for obj in activatables.duplicate():
            if is_instance_valid(obj):
                obj.activate(self)
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_X:
        fire_arc_tool()
    elif event is InputEventMouseButton and event.pressed \
        and event.button_index == MOUSE_BUTTON_RIGHT:
        # Right-click fires ONLY over actual World2D. Right-button drag from a
        # backed inventory still carries the complete physical item stack.
        fire_arc_tool()

func _physics_process(delta):
    equipment_runtime.tick(delta, equipment, inventory)
    counter = (counter+1)%9999999999

    # Handle jump.
    #if Input.is_action_just_pressed("action_1") and is_on_floor():
    #	velocity.y = JUMP_VELOCITY

    # keyboard
    var host: Node = get_node_or_null("/root/main")
    var blocked: bool = host != null and host.puzzle_active
    var direction: Vector2 = Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if blocked:
        mouse_target = null
    velocity = direction * SPEED
    if direction.x + direction.y > 0.1:
        mouse_target = null

    # mouse
    if mouse_target:
        velocity += (SCALE*position).direction_to(mouse_target) * SPEED
        if (SCALE*position).distance_to(mouse_target) < 10:
            mouse_target = null

    velocity = velocity.normalized() * SPEED * equipment_runtime.locomotion_multiplier(equipment, inventory)
    _test_unsecured_head(delta)

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

func service_reach() -> float:
    # Use the actual original PlayerReach collision circle (49 world units),
    # not an arbitrary 200-unit HUD drop radius.
    var shape: CollisionShape2D = $PlayerReach/CollisionShape2D
    var radius: float = shape.shape.radius if shape.shape is CircleShape2D else 49.0
    return radius * shape.global_scale.x + equipment_runtime.service_reach_bonus(equipment, inventory)

func diagnostic_level() -> int:
    return equipment_runtime.diagnostic_level(equipment, inventory)

func recharge_from(item: InvItem) -> bool:
    return equipment_runtime.recharge(item, inventory)

func fire_arc_tool() -> bool:
    # Short, electrically powered nonlethal emergency discharge. Deliberately
    # less useful than solving a route via maintenance, access or stealth.
    var shot: Dictionary = equipment_runtime.try_discharge(equipment, inventory)
    if not bool(shot.get("ok", false)):
        return false
    var origin: Vector2 = global_position
    var aim: Vector2 = get_global_mouse_position() - origin
    if aim.length_squared() < 0.001:
        aim = Vector2.RIGHT
    var destination: Vector2 = origin + aim.normalized() * float(shot["range"])
    var query := PhysicsRayQueryParameters2D.create(
        origin, destination, (1 << 14) | (1 << 15) | (1 << 19),
        [get_rid()])
    var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
    var collider: Node = hit.get("collider", null)
    var target: Node = collider
    if target != null and not target.is_in_group("enemies") and target.get_parent().is_in_group("enemies"):
        target = target.get_parent()
    if target != null and target.is_in_group("enemies") and target.has_method("stun_for"):
        target.stun_for(1.6)
    # Visual discharge is a separate short-lived world effect; ray physics
    # still determines the actual hit, not the particle animation.
    var flash: ArcFlash = preload("res://systems/effects/ArcFlash.gd").new()
    get_parent().add_child(flash)
    flash.global_position = origin + Vector2(0, -13.0 * global_scale.y)
    flash.burst(hit["position"] if hit.has("position") else destination)
    weapon_fired.emit(target, float(shot["energy_spent_wh"]))
    return true

func _unhandled_key_input(event: InputEvent) -> void:
    var host: Node = get_node_or_null("/root/main")
    if host != null and host.ui_captures_world_input():
        return
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if event.keycode >= KEY_1 and event.keycode <= KEY_9:
        use_quickslot(event.keycode - KEY_1)
    elif event.keycode == KEY_0:
        use_quickslot(9)

func use_quickslot(index: int) -> bool:
    if quickinventory == null or inventory == null or equipment == null:
        return false
    var linked: InvSlot = quickinventory.slot_at(index)
    if linked == null or not inventory.has(linked.item):
        return false
    var item: InvItem = linked.item
    if item.energy_wh > 0.0:
        if recharge_from(item):
            p("Installed %s. Suit charge: %.1f Wh." % [item.name, equipment_runtime.charge_wh])
            return true
        return false
    # Quick-access links no longer silently move equipment around the body.
    # Player has to drag equipment onto a physical body socket.
    return false

func _test_unsecured_head(delta: float) -> void:
    if equipment == null or inventory == null:
        return
    var item: InvItem = equipment.item_at("augment_head")
    if item == null or item.equipment_slots.has("augment_head"):
        unsecured_head_seconds = 0.0
        return
    if velocity.length() < 1.0:
        return
    unsecured_head_seconds += delta
    if unsecured_head_seconds < 2.0:
        return
    unsecured_head_seconds = 0.0
    equipment.assign("augment_head", null, inventory)
    if inventory.remove_item(item, 1):
        var dropped: Node2D = preload("res://items/item_world.tscn").instantiate()
        dropped.set("itemslot", InvSlot.new(item, 1))
        get_parent().add_child(dropped)
        dropped.global_position = global_position + Vector2(12, 0)
    p("Your hair lacked sufficient strength to hold %s in place." % item.name)
