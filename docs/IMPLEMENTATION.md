# Godot 4.7.2 migration and architecture notes

## Scope and status

This is an intentionally separate migration branch. The original main world remains, but its HUD inventory, terminal workbench bridge and equipment panel have been substantially integrated with the new Resource-driven systems. The branch updates the Godot project feature level to **4.7**, disables the old GitPlugin's automatic startup, and introduces a runnable **CircuitWorkbench.tscn** that can be opened separately from the legacy main scene.

No local Godot executable was available in the authoring environment. GitHub Actions has now successfully run **Godot 4.7.2** headless import, circuit/thermal/station unit tests, a camera-pan/zoom world picking regression with a HUD CanvasLayer, and scene startup for the workbench and legacy main world. Editor visual layout, mouse drag ergonomics, and full gameplay still require manual graphical testing. This is a technical foundation, not a claim that the whole game is migrated.

### Run the prototype

1. Open this branch with Godot **4.7.2 stable**.
2. Open `res://systems/circuits/CircuitWorkbench.tscn` and run current scene (F6).
3. Click the burnt resistor; click REMOVE SELECTED.
4. Select a 10-ohm resistor from the OptionButton, then click the vacated cell.
5. Press RUN. The load voltage should approach **4.533V** and become valid after its hold interval.
6. Parts, pins, placements, rotations, tolerances and failure properties are all visible in the Inspector via the `.tres` resource files.
7. Run `godot --headless --path . --script res://tests/circuit_smoke.gd` for regression checks (after editor import).

### Directory responsibilities

- `systems/circuits/CircuitPin.gd`: terminal placement on a part footprint.
- `CircuitPart.gd`: shared Inspector-authored template including ratings, thermal constants, model and pins.
- `CircuitPlacement.gd`: a particular part on a grid, with rotation and individual failure state.
- `CircuitBoard.gd`: authored dimensions, placements, objective, collision checks.
- `CircuitCompiler.gd`: deterministic port matching, isolated crossover conductors, resistive wire paths; builds a netlist without scene or PhysicsServer dependencies.
- `CircuitSimulation.gd`: nodal conductance solver, iterative simplified nonlinear devices, per-part energy dissipation and thermal damage.
- `CircuitBoardView.gd`: one Control renders/edit-selects the board; draggable placements use **Godot Control's own drag-and-drop API**.
- `CircuitWorkbench.gd/.tscn`: Godot UI nodes with exported resource authoring and a prototype Actuator puzzle.
- `systems/interactions/WorldHitTest.gd`: resolves world interaction in world canvas coordinates.
- `WorldDragBroker.gd`: separates a HUD drag preview from world hit testing and sends resource payloads through signals.
- `systems/station`: Inspector-authored power domains, consumer/converter dependencies, protocol interlocks and periodic availability updates.

### World-vs-HUD coordinate system contract

Old code in `main.gd`, `Player.gd` and `UI/IventoryItem.gd` mixes `CanvasLayer` HUD nodes with `World2D` physics queries and moving-camera hit tests. That is a brittle design. A UI `Control` should **not** own an `Area2D` simply to represent its drag/collision state in the level. The old code also repeatedly clones/reparents during drag.

**New contract:**
- HUD inventory: `Control` children in `CanvasLayer`; payloads are item `Resource` objects.
- World: `Node2D` and `PhysicsBody2D/Area2D` in the world canvas only.
- When dragging, display a non-pickable HUD-only preview. No world physics shape and no original node are moved.
- On drop, use the viewport mouse coordinate from `Node._input`, invert the world anchor's canvas transform and perform a world-only physics query. `WorldHitTest` shows that conversion explicitly.
- `Control._gui_input` mouse coordinates are control-local and **must not** be passed directly to world physics.
- Wire interaction via signals to world systems. A drop may be denied by distance, tools, inventory restrictions or station rules.

The older Godot/Camera2D behavior has **not** been reproducibly retested against 4.7.2. Regardless of whether the engine had a particular bug, a separation of canvas and physics responsibilities is a safer architecture.

### Circuit model and limitations

- Resistive/DC paths obey Kirchhoff current conservation, conductance matrices, Ohm's law and explicit source internal resistance.
- Wires use finite resistance through an isolated local hub per conductive group; multi-way splices and insulated crossovers do not create phantom shorts.
- Diodes use an on/off piecewise-linear forward drop.
- BJTs use simplified base-emitter conduction and beta-limited collector-emitter conductance. MOSFETs have a gate-threshold-controlled channel and zero ideal gate current. These are **game-level approximations** and **not SPICE-equivalent transistor models**.
- Each tick solves for node voltages, derives branch powers, integrates heat storage/cooling and burns components open at a temperature limit.
- Floating branches are stabilized by a tiny shunt-to-reference for numerical conditioning; use actual meter/current diagnostics to verify consistency.
- Simulation is DC/quasi-static. Backward-Euler capacitors and inductors are implemented, but no high-frequency switching transients, AC phases, hysteresis, mechanical contacts, arcs, internal conductor voltage gradients, or non-ideal diode recovery are yet implemented.
- A circuit editor is authored as regular Godot `Resource` and `Control` objects. The old per-cell 2D physics layout is deliberately not reused.
- Live board editing is intentionally disabled while solving. Later, add a safe "de-energize / pull live wire" mode with arc and burn events.
- Solver validation and current/thermal ratings are preliminary; some semiconductor configurations may fail to converge and will report that fact instead of claiming a valid solution.

### Station network status

Power buses carry `domain`, nominal voltage, capacity and intermittent duty cycle. Devices declare a supply bus, electrical demand, protocol credentials, and dependencies. Converters can bridge power domains explicitly; there is no automatic interoperability. This is **availability scheduling**, not yet a network-wide continuous power-flow solver. Future versions will add bus voltage sag, physical converters, battery state, shorts, HVAC/atmosphere equations, delayed state machines, protocol simulators, adversarial AI actions, and a unified save-game/event log.

## Migration roadmap and exit criteria

**M0 — make the prototype trustworthy (current branch).** Run Godot 4.7.2 import/CI tests; fix all parse errors. Unit tests: 5V series load, resistor failure, rotated ports, true junction and isolated crossover, thermal burn. Confirm the editor opens without a broken native Git GDExtension. Do not merge before these checks.

**M1 — replace cross-canvas UI.** Convert legacy inventory widgets to data-based drag via `WorldDragBroker`. Make world interaction query one canvas. Test at camera positions (0,0), (500,500), moving and zoomed, at different viewport sizes. Preserve item metadata and stacked inventory. Eliminate per-cell physics and all drag clone tricks.

**M2 — mathematical correctness.** Add a fixed-step solve engine with sparse/modified nodal analysis, robust convergence, open/short/overcurrent warnings, SPICE comparisons for a library of golden test circuits. Validate BJT, MOSFET, temperature-dependent resistance and diode characteristics. Add a virtual multimeter, probes, logic analyzer and thermal camera.

**M3 — reusable puzzle authoring.** Build an Inspector plugin for board visualization, palette constraints, damaged starting state, objectives based on voltage/current/timing and event signals. Support undo/redo, resource references, scalable multi-cell footprints, rotation and serialized board snapshots. Introduce physical wires as finite supplies in the inventory.

**M4 — world systems.** Interconnect electrical, automation, environmental, mechanical, network and protocol systems through typed ports. Start with one door/airlock that has multiple power domains and genuine safety/security requirements.

**M5 — systemic adversary and survival economy.** A station AI with visibility, reachability and finite authority, sabotage capabilities, event trace and counterfactual player options. Real tool heads, solder, consumables, extraction and salvage quality. Track persistent global state and route-dependent consequences.

**M6 — content.** Author 20+ interdependent repair scenarios with several non-prescribed solutions each, technical documents and interesting failure cascades. Avoid direct combat as the assumed route.


## Integrated playable station slice (added)

`res://systems/station/StationMaintenanceBay.tscn` is the new Godot-native **systems gameplay integration scene**. It contains an instance of `StationNetworkDemo.tscn`, a single-compartment atmosphere, a finite-capability station security AI, the reusable circuit workbench and an operations/inventory/journal UI. It is not yet integrated with the original 2D exploration map.

The station has three authored power domains (AC industrial, 48V service, pulsed HV), an AC-to-DC converter, a damaged ventilation drive, a security controller, gas injection valve, robot charge station and a maintenance bulkhead.

The bulkhead requires **four independent conditions**: sufficient DC power, a successful repair of its electrical actuator driver, a service-protocol authorization and safe atmosphere. Repairing a relay cannot bypass the protocol; spoofing the protocol cannot power a motor; a live AC isolation procedure prevents safe ventilation repair; a halted fan cannot clear the security AI's inert gas.

The level starts with finite solder, resistors and wire, but no Robertson screwdriver or protocol analyzer. A service-deck salvage excursion acquires the screwdriver at the cost of station time and AI attention. A power-isolated repair consumes solder and wiring; assembling a replacement circuit component also costs solder. Service tools survive use; failed components become scrap. There is no generic infinite inventory when this workbench is embedded in the bay.

The gameplay scene records events, displays denial reasons and measurement diagnostics, and supports JSON-safe snapshots in `user://maintenance_bay_v1.json`. Data is authored as Godot `.tres` resources (inventory, equipment, repair procedures, circuit parts) and `.tscn` scenes (station graph, UI and workbench). No per-slot physics Areas are needed.

The workbench now supports Inspector-authored capacitor/inductor parts, backward-Euler companion equations for RC/RL transient behavior with series resistance, and a live component meter with pin voltage, current, heat and wattage. Its semiconductor approximations remain intentionally less accurate than the linear/reactive solver.

CI covers the entire maintenance chain, scarcity transactions, converter failure, contaminated-air purge, inventory and circuit snapshot restoration, RC/RL response, isolated crossings, thermal failure, and camera pan/zoom picking. The CI workflow explicitly rejects script exceptions. There has been **no manual graphical playtest** of this scene.

### Known limitations in this slice

- The simulated "backtracking" is currently a timed service-deck action; there is not yet traversable deck-level layout or a physical screwdriver pickup.
- The security handshake is a tool-gated logical simulation; an actual packet-level challenge/response puzzle is future work.
- AI gas attack is resource-bounded and tied to a powered device, but the opponent does not yet plan across an entire station graph.
- Atmosphere is a well-mixed single compartment, not a 3D fluid dynamics simulation.
- Thermal energy is integrated using fixed steps, but engine physics, short-circuit arcs and AC power flow remain simplified.
- Gameplay visuals and accessibility/legibility require graphical validation before replacing the existing main scene.

## Legacy audit

`UI/circuit_puzzle.gd` currently searches `Area2D` overlaps and recursively traverses whole components; this can falsely join the two paths of an insulated crossing. `UI/PuzzleSlot.gd` relies on node names and sprite dimensions for geometry and has a suspicious drag-override conditional using `disallow_rotate`. `interactibles/Terminal.gd` has access flags but not a reliable circuit-to-terminal solver connection. These remain in the project to avoid breaking the old game before the replacement has integration tests.

**Decision:** migrate one vertical slice at a time, replace the old source only after new behavior is validated, and use the Godot editor to author scenes/resources rather than embedding entire levels in code.

## Main-world inventory index, crafting and equipment mannequin

The original game HUD now instantiates `res://UI/Inventory.tscn` for the backpack and quickbar and `res://UI/EquipmentMannequin.tscn` in place of the former noise-texture display. These are **native editable Godot scenes** using `Control._get_drag_data/_can_drop_data/_drop_data`, not physics Areas or duplicated world bodies. `main.gd` binds both indices and the mannequin to the **same player backpack**, so viewing/equipping/quickbinding never creates phantom extra stock.

**Controls and feedback:**

- Press the existing inventory action to show the index and body profile. Hover an item to see exact quantity, description, and available forward combination recipes; drag it onto a compatible ingredient to craft.
- Drag side cutters onto heavy cable to create **three usable wire segments** without consuming the tool. Combine wire with one solder segment to create an **insulated jumper** linked to the `wire_straight.tres` board component. Other related authored recipes include contacts plus solder. Assembling that part on a circuit board still consumes *installation* solder.
- Drag a weapon or compatible augmentation from the index to one of eight anatomical sockets. Equipment is a **reference to owned physical stock**; equipping one pistol into two weapon sockets requires two actual pistols. Socket restrictions, automatic unequipping after item loss, and nonduplicating moves are enforced by `EquipmentLoadout.gd`.
- A search field filters name, shorthand and description without changing inventory. A category dropdown filters weapon/augment/tool/material/food, with an explicit Sort/Group control. The index displays **unit counts and stack counts** for whole inventory and search results. Stack badges show ×1 as well as larger amounts.
- Quickbar entries are **links** to backpack stock and show the real available quantity; removal of the last owned item expires the link. Dropping inventory outside the HUD creates one genuine world pickup per item and removes exactly one; picking it up again restores the count.

**Model invariants:**

- `Inv.gd` stages changes before committing, sums counts rather than occupied slots, and automatically merges stacks using explicit stable `InvItem.item_id` identities or Resource paths. Duplicate item Resources with the same stable ID group correctly. Stack limits and fixed slot capacity cannot silently discard items. Runtime player models duplicate their starter templates to avoid cross-instance state leaking.
- `InventoryOperations.gd` stages **both inventories** when crafting or dragging across containers. It consumes recipe quantities across multiple stacks, handles reusable tool catalysts, reverses valid recipes on either drag orientation, merges existing stacks, allows safe cross-container swaps, and rejects recipes with invalid output or insufficient space **without partial consumption**.
- `EquipmentLoadout.gd` checks physical stock, slot affinity and weapon/augmentation type, exposes a JSON-compatible snapshot and validates restorations transactionally. The centered mannequin is procedurally drawn by `MannequinCanvas.gd` with eight independently editable slot Buttons placed around the silhouette rather than obscuring it.

Automated Godot 4.7.2 tests: `res://tests/inventory_smoke.gd` (grouping, identity, category/search counts, exact recipe costs, multi-stack consumption, swaps, overflow atomicity, equipment validity and snapshot restoration, drag control wiring) and `res://tests/inventory_world_smoke.gd` (real pickup/drop conservation, a repair terminal using the same backpack, and crafting a jumper which maps to a usable electrical component). The `main.tscn` and both standalone system scenes receive headless startup checks. **These do not substitute for an interactive visual playtest.**

## Follow-on pass: powered equipment, crafting ledger, main-world saves

### Gameplay effects of installed gear

An equipment slot is no longer only cosmetic. The `EquipmentRuntime.gd` rules operate on **equipped actual backpack stock** and a finite 24 Wh suit power store (16 Wh initially charged). Each powered augmentation draws its own Watts each simulation tick:

- **Servo forearm brace**: ×1.16 walking speed and +32 world-maintenance reach while powered, with 4.5 W consumption.
- **Neural diagnostic regulator**: additional terminal/robot diagnostic information in the original-world hover tooltip while powered, with 1.25 W consumption.
- **Arc maintenance pistol**: a short-range (150 world unit) 0.45 Wh electrical pulse, maximum one per 0.75 seconds, temporarily disables a robot's shooting/motion for 1.6 seconds. This is an emergency utility tool, not an intended combat progression path.

A new authored `items/power_cell.tres` provides 12 Wh usable charge per consumed cell; initial physical inventory contains two. **Double-click** the power cell in the backpack to refill the suit if not already full. The mannequin displays actual Wh remaining and only counts owned equipped weapons/augmentations. At zero Wh, powered locomotion/reach and diagnostics stop working; firing is blocked. The implementation is explicitly a simple energy-budget model, not a battery chemistry simulation.

### Visible recipe index

In addition to dragging ingredients onto each other, the backpack now contains an **ASSEMBLE** row. This enumerates `InvItem.combos` authored in the Inspector from items the player owns, including missing target materials, output quantity and reusable catalysts. Selecting a craftable entry and pressing ASSEMBLE invokes the existing atomic inventory operation. No separate crafting rules are hardcoded into the UI; physical stock must be available and there must be enough capacity for the result. This enables forward recipe discovery without arbitrary "click every item pair" guessing.

The toolbar uses two rows to keep Search, Sort/Group, Save/Load and Assemble visible at the narrower original HUD widths.

### Main-world saves

`WorldSave.gd` creates a versioned JSON save in `user://cybernex_save_v1.json`. Use **SAVE** and **LOAD** in the full backpack's action row. It captures:

- Physical backpack stacks and exact units; linked quickbar slots; mannequin slots and installed item identities.
- Player world position, health, suit energy and discharge cooldown.
- Terminal and desk looting/authorization/activation state.
- Current world pickup positions, item identity and stack sizes; robot position/health and removal of already-defeated robots.

The loader resolves items only through a known catalogue of Inspector-authored item Resources, preflights all inventories, loadout, positions and world pickup records, and commits after validation. Malformed versions and unknown items are rejected rather than partially applied. Runtime player inventory Resources, terminal loot and equipment are per-scene instances rather than shared global templates. After a successful load the three HUD panels are rebound to the restored authoritative stock.

**Save coverage is intentionally scoped to the legacy original world**. It is not yet a complete global save for the separate `StationMaintenanceBay.tscn` scenario (which has its own snapshot). Nor does it persist arbitrary future mod/plugin-added item IDs, live projectiles, animation playback, user settings or all possible environmental effects.

### Canvas hover cleanup

The original `main.tscn` now owns a **WorldHitTest Node2D as an Inspector-visible world child**. Its physics canvas comes from the Player's real `PhysicsBody2D`; viewport-to-world coordinates derive from the camera transform. Old `main.gd` queried both a HUD CanvasLayer and World2D physics space and sorted misleading collision results. The replacement performs a single world-only hit query, while native Godot Controls use GUI tooltips. A powered neural diagnostic augmentation can add actual terminal accessibility or robot chassis-integrity data. The old 4.3 engine regression itself is not claimed reproduced or fixed inside Godot; this removes the cross-canvas design dependency.

### Added test coverage

`tests/equipment_save_smoke.gd` checks suit loadout energy consumption, deactivation on low battery, physical cells, reusable weapon cooldown and the complete original-world save/reload round-trip. Corrupt saves and invalid item IDs must fail atomically. `tests/inventory_smoke.gd` now covers the discoverable ASSEMBLE control, missing-stock recipes, duplicate Resource item identity, and explicit versus automatic grouping. `tests/inventory_world_smoke.gd` additionally validates that the original world's physics picking maps camera/world coordinates correctly.

Tests execute under GitHub Actions' Godot 4.7.2 headless runner. **Headless checks cannot establish that the new UI is attractive, responsive on every screen size or suitable for controller/touch use.** Leave this as a draft for visual playtesting.

## 720p UI and physical tool-drag follow-up

The central game interactions retain the original visual/physical rules: physical items drag from the backpack onto the World2D, while a terminal temporarily docks the same inventory drawer on the right. The compact exploration drawer remains on the left, leaving reach-accessible level geometry near the player exposed. Seven columns of gray rounded backpack sockets are shown, including empty cells; the panel's original nuisance Sort/Assemble/help rows are hidden instead of teaching combinations outright. The previous bottom event journal remains the sole narrator. Quick access hides only during the terminal puzzle. Section arrows can cycle the drawer through Backpack, Body Systems, Notes, Map and future late-game meters.

The original `assets/tileset_electronics.png` art is used by Godot `AtlasTexture` on the new circuit-part `.tres` files; the original resistor band atlas `UI/resistor_color_atlas.tres` is tinted with its electrical code, so resistor numeric values are not displayed to the player without later meter unlock. Oversized MOSFET resources keep 2×2 cell footprints, with pins rotated as actual edge coordinates. Right-click rotates removable parts on the board. A black corner triangle marks a fastened part, while a static subtle green rim marks movable ones (no flashing animation).

Further fixes from this pass: start the mannequin scene's unused panel hidden so its minimum width never stretches a 720p backpack on the first frame. Keep the actually authored 316×370 sidebar sprite and physical socket coordinates at native UI scale, with artwork rendered from one 450×430 coordinate space. Rebalanced the stable side-drawer/quickbar width for 1280×720 up to 1920×1080.

**New direct circuit repair interaction:** side cutters held in the physical inventory can be dropped on a failed-open component in the circuit board. It must be unfastened, fit the extraction space, be de-energized and have usable side cutters; a successful action extracts the destroyed part as scrap without consuming the tool. This follows the same tested `_remove_selected()` salvage path but no longer requires players to discover a REMOVE control. Real replacement parts still need a spare and solder (or suitable tape for wire). The repair event is routed through the existing lower journal in the main world.

`tests/inventory_world_smoke.gd` now performs the complete cut-and-replace operation with native Godot `_can_drop_data/_drop_data` on the real door panel, verifying no ghost stock and no consumed cutters. Godot's headless test does not prove mouse-drop ergonomics visually; graphical tests still need to verify the intended 720p interaction.
