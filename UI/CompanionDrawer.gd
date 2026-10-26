extends PanelContainer
class_name CompanionDrawer

## An independent, matching instrument/inventory pager to the RIGHT of
## the fixed left-hand anatomical panel. Inventory item views share the
## original physical backpack; the second view is not a stock clone.
const PAGES := ["BACKPACK", "MULTIMETER", "OSCILLOSCOPE", "NOTES"]
var page_index: int = 0
@onready var backpack_view: InventoryView = $Layout/InventoryItems

func _ready() -> void:
    $Layout/Nav/Previous.pressed.connect(func() -> void: select_page(page_index - 1))
    $Layout/Nav/Next.pressed.connect(func() -> void: select_page(page_index + 1))
    select_page(0)

func bind_inventory(pack: Inv) -> void:
    backpack_view.configure(pack, null, "backpack")
    select_page(page_index)

func select_page(index: int) -> void:
    page_index = posmod(index, PAGES.size())
    $Layout/Nav/Section.text = PAGES[page_index]
    $Layout/InventoryItems.visible = page_index == 0
    $Layout/Info.visible = page_index != 0
    if page_index == 1:
        $Layout/Info.text = "Multimeter not acquired."
    elif page_index == 2:
        $Layout/Info.text = "Oscilloscope not acquired."
    elif page_index == 3:
        $Layout/Info.text = "No notes selected."
