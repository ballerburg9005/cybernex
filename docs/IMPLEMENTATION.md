# Godot 4.7.2 migration and architecture notes

## Scope and status

This is an intentionally separate migration branch. The existing main world scene and old inventory gameplay are not yet replaced. The branch updates the Godot project feature level to **4.7**, disables the old GitPlugin's automatic startup, and introduces a runnable **CircuitWorkbench.tscn** that can be opened separately from the legacy main scene.

No local Godot executable was available in the authoring environment. GitHub Actions has now successfully run **Godot 4.7.2** headless import, circuit/thermal/station unit tests, a camera-pan/zoom world picking regression with a HUD CanvasLayer, and scene startup for the workbench and legacy main world. Interactive Inspector editing, rendering, mouse drag-and-drop, and full gameplay still require manual visual testing. This is a technical foundation, not a claim that the whole game is migrated.

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
- Simulation is DC/quasi-static. No capacitors, inductors, switching transients, AC phases, hysteresis, mechanical contacts, arcs, internal conductor voltage gradients, or non-ideal diode recovery are yet implemented.
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

## Legacy audit

`UI/circuit_puzzle.gd` currently searches `Area2D` overlaps and recursively traverses whole components; this can falsely join the two paths of an insulated crossing. `UI/PuzzleSlot.gd` relies on node names and sprite dimensions for geometry and has a suspicious drag-override conditional using `disallow_rotate`. `interactibles/Terminal.gd` has access flags but not a reliable circuit-to-terminal solver connection. These remain in the project to avoid breaking the old game before the replacement has integration tests.

**Decision:** migrate one vertical slice at a time, replace the old source only after new behavior is validated, and use the Godot editor to author scenes/resources rather than embedding entire levels in code.
