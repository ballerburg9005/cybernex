# Follow-up to gameplay review — October 26, 2026

This is an incremental **draft branch** review response. The main branch is left untouched. Automated tests use Godot 4.7.2; visual input/rendering in a normal game window still needs to be evaluated.

## Electronics: original artwork, honest information

- The original `assets/tileset_electronics.png` is used directly for resistor, wire, transistor, MOSFET, rectifier/diode, supply, GND and output images through Godot-native `AtlasTexture` subresources.
- Resistor color bands come from **the original `UI/resistor_color_atlas.tres` band masks** rather than procedural generic colored rectangles. The resistance number is not printed. Nominal ohms continue to be authored in the `CircuitPart` Inspector resource so the solver uses the actual component value.
- N- and P-channel MOSFETs are genuinely two-by-two-cell components with individual edge leads. Pin coordinates rotate with the footprint, not merely with the sprite. Fixed parts receive a small black corner marker; removable parts have **static**, muted green outlines (no flashing).
- Board labels are reduced to readable, outlined labels such as `GND`, `IN`, `MOTOR`, `NMOS`. Bare source/load voltage, current, watts and temperature readings are **not displayed** without an actual instrument. In this pass the multimeter and oscilloscope pages stay unavailable.
- The workbench has a 9×7 default grid, native scrolling when its authoring board exceeds its viewport, and a single power control under the board. Old prototype action buttons and heavy explanatory labels are hidden.
- Right-click a movable part on the board to rotate it. Drag a real compatible spare **from the inventory** to a free pad to install, rather than selecting a dropdown. Drag a removable part back into the backpack to extract it. Extracting intact soldered components spends solder; breaking away burned electronics needs cutters; taped leads can be peeled off. Fixed parts cannot be moved.
- Insulation tape is a discoverable finite consumable in one original-world desk. Wires can use it instead of solder, but tape-secured placements have **0.32Ω extra contact resistance**; the actual compiler/simulator includes this in current and Joule heating. Quality is persisted in circuit snapshots. Solder is still needed for other component installation.

## Reusable sidebar and HUD

- The same `InventoryView` is used in exploration and electronics contexts. A paged drawer contains backpack, body, notes, map, multimeter and oscilloscope sections, with ▲/▼ cycling infinitely. The latter four sections are initial placeholders, not a claim that a full PDA or meter is already implemented.
- During exploration the drawer occupies about 29% of the **left** edge so the middle of the world remains accessible; during circuit repair it moves to the **right**, with the workbench filling the remainder of the upper screen. It stays the same size across modes.
- Inventory grid shows **all authored cells**, even empty ones, with gray rounded backgrounds. Explicit Recipe/ASSEMBLE, Sort, category filters, search, extra help text, and large "quick access" captions are no longer shown during gameplay. Combining remains native item-on-item drag, not a menu command.
- The preexisting event bar provides the narration and now has a dark backing and smaller, higher-contrast type. On entering a puzzle, the quickbar disappears and the event bar can expand across the entire bottom edge. Exiting restores the exploration quickbar.
- The mannequin has eight individually editable sockets and no forced auto-placement. It accepts odd item placements. Only parts mounted in actual supported sockets provide electrical benefits. An unsupported head-mounted item will fall after movement, enter the physical world, and report why in the event log.

## World interactions, physics and scarcity

- An inventory drag released over reachable world physics now invokes the object's existing `combine(InvSlot)` interaction first, **before** considering dropping a physical item.
- The release point is converted once from viewport pixels to global world coordinates, then compared with the player's reach using the **same coordinate space**. The old comparison mixed World-local and global coordinates, creating the false out-of-range responses.
- The old exposed-wire wall again accepts a side cutter and releases actual collectible world-wire stacks. Its limited extraction counter is saved; reloading no longer regenerates already-cut wiring.
- Dragging a tool onto a robot hits it for modest physical damage without consuming the reusable tool; unsupported drops become genuine world pickups, not fake HUD physics clones.

## Remaining work / visual review

- Multi-card electronic boards and actual multimeter/oscilloscope lead placement need a dedicated interface and additional station logic.
- PDA/map pages currently reserve space and navigation but do not yet have document collections or cartographic data.
- Different physical joining operations need additional parts (e.g., wire ties, clamps), long-term joint aging and insulation-specific failure models.
- World target prioritization in busy overlapping scenes, mouse releases near drawer edges, full 720p→1080p layout on different desktop scaling settings, keyboard accessibility, and graphical appearance need an interactive Godot run. CI here is **headless**.
- The integration maintenance bay remains a separate scenario; it still needs the original map/terminal system wired into a single traversable station.

Tests: `tests/circuit_smoke.gd` for 2×2 rotated leads, atlas sprite dimensions and contact resistance; `tests/inventory_world_smoke.gd` for 720p HUD/puzzle layout and physical circuit assembly; `tests/world_interaction_smoke.gd` for cutting wall wires and harming a bot by dragging tools; and existing inventory, save, camera and station smoke tests.
