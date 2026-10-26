extends PanelContainer
class_name DeskInspection

## One reusable full-size panel for desk contents, notes and computer controls.
## The REAL backpack remains visible to the right on every page. No world
## physics item is ever created by dragging onto the pane.
signal closed

var loot: Inv
var backpack: Inv
var journal: Callable
var page_index: int = 0
var computer_powered: bool = true
const PAGES := ["CONTENTS", "NOTES", "COMPUTER"]

@onready var desk_view: InventoryView = $Layout/Contents/DeskItems
@onready var bag_view: InventoryView = $Layout/Contents/Backpack

func _ready() -> void:
    $Layout/Navigation/Previous.pressed.connect(func() -> void: _select_page(page_index - 1))
    $Layout/Navigation/Next.pressed.connect(func() -> void: _select_page(page_index + 1))
    $Layout/Navigation/Close.pressed.connect(close)
    $Layout/Bottom/TakeAll.pressed.connect(take_all)
    $Layout/Bottom/Power.pressed.connect(toggle_power)
    desk_view.feedback.connect(_log)
    bag_view.feedback.connect(_log)
    get_viewport().size_changed.connect(reflow)
    reflow()

func configure_contents(incoming: Inv, bag: Inv, on_event: Callable) -> void:
    loot = incoming
    backpack = bag
    journal = on_event
    desk_view.configure(loot, null, "backpack")
    bag_view.configure(backpack, null, "backpack")
    _select_page(0)

func reflow() -> void:
    if not is_inside_tree():
        return
    var view: Vector2 = get_viewport_rect().size
    var wanted: Vector2 = Vector2(minf(1130.0, view.x - 28.0), minf(520.0, view.y - 110.0))
    set_anchors_preset(Control.PRESET_TOP_LEFT)
    grow_horizontal = Control.GROW_DIRECTION_END
    grow_vertical = Control.GROW_DIRECTION_END
    position = Vector2((view.x - wanted.x) * 0.5, maxf(8.0, (view.y - wanted.y - 70.0) * 0.5))
    size = wanted

func _select_page(next: int) -> void:
    page_index = posmod(next, PAGES.size())
    $Layout/Navigation/Page.text = "DESK / %s                        BACKPACK" % PAGES[page_index]
    desk_view.visible = page_index == 0
    $Layout/Contents/DetailPanel.visible = page_index != 0
    $Layout/Bottom/TakeAll.visible = page_index == 0
    $Layout/Bottom/Power.visible = page_index == 2
    if page_index == 1:
        $Layout/Contents/DetailPanel/Description.text = "Papers and loose sheets."
    elif page_index == 2:
        $Layout/Contents/DetailPanel/Description.text = "Workstation PC, %s." % ("ON" if computer_powered else "OFF")

func toggle_power() -> void:
    computer_powered = not computer_powered
    _select_page(page_index)
    _log("PC powers on." if computer_powered else "PC shuts off.")

func take_all() -> bool:
    if loot == null or backpack == null:
        return false
    var staged: Inv = backpack.duplicate(true)
    var moved: int = 0
    for slot in loot.items:
        if slot == null or not slot.occupied():
            continue
        if not staged.add_item(slot.item, slot.count):
            _log("The backpack is full.")
            return false
        moved += slot.count
    if moved == 0:
        _log("The desk is empty.")
        return true
    var initial: Array[Dictionary] = backpack._state()
    if not backpack._commit(staged._state()):
        return false
    var emptied: Array[Dictionary] = loot._state()
    for i in range(emptied.size()):
        emptied[i] = {"item": null, "count": 0}
    if not loot._commit(emptied):
        backpack._commit(initial)
        return false
    _log("%d items recovered from the desk." % moved)
    return true

func _log(value: String) -> void:
    if journal.is_valid() and not value.is_empty():
        journal.call(value)

func close() -> void:
    closed.emit()
    queue_free()
