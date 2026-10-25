@tool
extends Resource
class_name SalvageStock

## One kind of repair material or reusable tool. Quantity is serialized in
## a save snapshot, never in a globally preloaded item template.
@export var item_id: String = ""
@export var display_name: String = ""
@export_range(0, 9999, 1) var quantity: int = 0
@export var is_tool: bool = false
@export var description: String = ""
