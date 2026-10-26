extends PanelContainer
class_name DeskInspection

## One reusable full-size panel for desk contents, notes and computer controls.
## The REAL backpack remains visible to the right on every page. No world
## physics item is ever created by dragging onto the pane.
signal closed
signal power_changed(powered: bool)

var loot: Inv
var backpack: Inv
var journal: Callable
var page_index: int = 0
var computer_powered: bool = true
var authored_notes: String = ""
var authored_computer_readout: String = ""
const PAGES := ["CONTENTS", "NOTES", "COMPUTER"]

@onready var desk_view: InventoryView = $Columns/DeskPanel/Layout/Contents/DeskItems
@onready var bag_view: InventoryView = $Columns/BackpackPanel/BackpackLayout/Backpack

func _ready() -> void:
    $Columns/DeskPanel/Layout/Navigation/Previous.pressed.connect(func() -> void: _select_page(page_index - 1))
    $Columns/DeskPanel/Layout/Navigation/Next.pressed.connect(func() -> void: _select_page(page_index + 1))
    $Columns/DeskPanel/Layout/Navigation/Close.pressed.connect(close)
    $Columns/DeskPanel/Layout/Bottom/TakeAll.pressed.connect(take_all)
    $Columns/DeskPanel/Layout/Bottom/Power.pressed.connect(toggle_power)
    desk_view.feedback.connect(_log)
    bag_view.feedback.connect(_log)
    get_viewport().size_changed.connect(reflow)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color("#161e23")
    panel_style.border_color = Color("#4d6369")
    panel_style.set_border_width_all(1)
    panel_style.content_margin_left = 5
    panel_style.content_margin_right = 5
    panel_style.content_margin_top = 5
    panel_style.content_margin_bottom = 5
    add_theme_stylebox_override("panel", panel_style)
    reflow()

func configure_contents(incoming: Inv, bag: Inv, on_event: Callable,
        notes: String = "", computer_text: String = "", powered: bool = true) -> void:
    loot = incoming
    backpack = bag
    journal = on_event
    authored_notes = notes
    authored_computer_readout = computer_text
    computer_powered = powered
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
    $Columns/DeskPanel/Layout/Navigation/Page.text = "DESK / %s" % PAGES[page_index]
    desk_view.visible = page_index == 0
    $Columns/DeskPanel/Layout/Contents/DetailPanel.visible = page_index != 0
    $Columns/DeskPanel/Layout/Bottom/TakeAll.visible = page_index == 0
    $Columns/DeskPanel/Layout/Bottom/Power.visible = page_index == 2
    if page_index == 1:
        $Columns/DeskPanel/Layout/Contents/DetailPanel/Description.text = authored_notes if not authored_notes.is_empty() else "Papers and loose sheets."
    elif page_index == 2:
        $Columns/DeskPanel/Layout/Contents/DetailPanel/Description.text = (authored_computer_readout if not authored_computer_readout.is_empty() else "Workstation PC.") if computer_powered else "Black display."

func toggle_power() -> void:
    computer_powered = not computer_powered
    power_changed.emit(computer_powered)
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
