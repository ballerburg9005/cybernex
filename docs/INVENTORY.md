# Cybernex Inventory Index, Crafting and Cybernetic Mannequin

## What changed in the original world

Open the **normal inventory screen** in `main.tscn`. The old `noise.jpg` inventory rectangle now contains `UI/EquipmentMannequin.tscn`: a Godot-authored suit silhouette with eight individually placeable Button sockets. The grid next to it is `UI/Inventory.tscn`, also entirely native Control nodes.

Inventory UI no longer creates UI `Area2D` collision boxes, duplicates world physics items while dragging, polls every 200ms, or invokes child `_ready()` methods to refresh itself. One authoritative `Inv` resource owns each stack; `Resource.changed` updates views when a mutation actually occurs. Inventory controls use Godot `_get_drag_data`, `_can_drop_data` and `_drop_data`.

### Backpack behavior

- **Correct totals:** `Inv.count(item)` sums the `count` of every valid stack. `count()` sums all actual items. Empty/missing item placeholders count as zero.
- **Auto grouping:** pickups add to existing stacks first. `Inv.normalize()` packs duplicates, respects `max_stack`, and refuses to silently discard overflowing stacks. `sort_by_category()` groups stacks by category, then name.
- **Compact visual index:** display actual occupied stacks plus some empty placement cells instead of showing 50 unused squares. The grid supports filters for tools, weapons, augmentations, materials and food, and a visible **SORT / GROUP** action. Badges show true quantities.
- **Transactional movement/crafting:** `InventoryOperations.move_or_combine()` stages all changes. Failed recipes, incompatible targets or insufficient output capacity leave all original ingredient counts unchanged. Matching stacks merge; distinct stacks inside one backpack swap.
- **Hotbar references:** the nine quick-access slots point at actual items in the backpack rather than minting extra copies. Losing the last item automatically clears stale shortcuts.
- **External world inventory:** nearby world loot panels use the same native grid model. The physical item on the floor is the only physics object, and moving one from the backpack into the world subtracts exactly one item using a viewport-to-world coordinate transform. Picking it up adds it back.

### Recipes included

These are Inspector-authored `InvCombo` Resources on the item `.tres` files; either drag orientation works:

| Combination | Output | What gets consumed |
|---|---|---|
| Side cutters + heavy cable | 3 thin usable wires | Heavy cable, not cutters |
| Side cutters + loose wire | 2 prepared copper contacts | 1 wire, not cutters |
| Wire + solder | 1 insulated electronic jumper | 1 wire and 1 solder |
| Prepared contacts + solder | 1 insulated electronic jumper | 1 contact and 1 solder |

The output is a real item in the backpack, with a proper stack and count. `items/wire_bridge.tres` references `systems/circuits/parts/wire_straight.tres` through an exported `circuit_part` Resource, **so it is usable in a real circuit board**, not merely named salvage. Installing the part requires another solder segment.

The original map's `World/Terminal` is configured to open `CircuitWorkbench.tscn` as a circuit puzzle. A replacement `items/resistor10.tres` and solder must be in the player backpack to repair its burned resistor. When its circuit meets the voltage objective the world terminal emits its original activation signal to the connected door. The authored workbench item palette maps real `InvItem` Resources to authored `CircuitPart` Resources and does not offer free infinite stock in this mode.

The standalone maintenance-bay demo still uses its own `SalvageInventory` resource. Those are intentionally independent scenes for now; a later migration should unify the resource stores and preserve the persistence rules.

### Equipment mannequin

The mannequin silhouette itself is drawn by `MannequinCanvas.gd`; **the slots are real editable Button nodes in the Godot scene**, not collision geometry or hardcoded pixel hitboxes:

- Primary and secondary weapon hand
- Head, torso, left arm, right arm, legs, neural augmentation

`EquipmentLoadout.gd` references `InvItem` resources already owned by the backpack; equipping never changes its counts or creates duplicate objects. A second copy of the same weapon can occupy a second hand only if the backpack contains at least two. Gear with incompatible `equipment_slots` is rejected. Moving equipment between sockets is supported, and deleting/losing the last copy clears stale equipped references.

Starter equipment is authored in `UI/player_loadout.tres` and referenced directly by `player.tscn`. The world map starter inventory includes materials, two weapon/augmentation types, a spare resistor and salvage tools, so the UI can be exercised immediately.

### Tests

- `godot --headless --path . --script res://tests/inventory_smoke.gd`: conservation across stacks, overflow, duplicate grouping, sorting, cutter recipes, reversible wire+solder crafting, full-storage rollback, shortcut and mannequin counting, equipment dragging.
- `godot --headless --path . --script res://tests/inventory_world_smoke.gd`: actual world pickup/drop round trip, coordinate conversion, out-of-reach handling, world terminal repair, consumption of physical resistor and solder, crafted jumper installation into the circuit editor.
- Existing `tests/coordinate_smoke.gd` checks moving/zoomed Camera2D hits with the CanvasLayer present.

CI additionally runs the original map, the maintenance-bay scenario, and the electrical test suite under Godot 4.7.2.

## Limits

This is a **headless-tested implementation**, not a claim of manually verified drag-and-drop ergonomics or sprite/art direction. UI sockets remain schematic placeholders and augmentation effects/weapon ballistics have not been integrated with combat or station logic. Scavenging, terminal visuals, categories, real item capacity and tool use all have room for deeper design. The old animated world object is intentionally kept as an actual physics body, but the obsolete dual-space HUD physics duplication has been deleted.
