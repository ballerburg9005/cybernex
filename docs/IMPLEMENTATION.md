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
