# CYBERNEX — Design vision

**Genre:** systemic survival-puzzle immersive sim, strongly inspired by the hostile-station exploration of System Shock, but with a far greater emphasis on diagnosing and normalizing a broken technical environment.

## Central premise

The station was designed for engineers, not players. Most of its complexity is never strictly necessary for completion. That surplus of believable machinery is intentional: exploration and curiosity must reward the player with understanding, shortcuts, failure modes, and emergent solutions.

There are no generic green-key/red-key doors. A door may have an actuator, local DC conversion, emergency manual release, identity challenge, redundant safety PLC, thermal fuse, network interlock, physical hinges, and a hostile supervisor that can revoke authorization. Its behavior is not controlled by an arbitrary "door_solved" flag. It opens when the interacting subsystems actually permit it.

### Non-negotiable gameplay rules

1. **Understanding beats damage output.** Enemy fights must be risky, expensive, noisy and often self-defeating. Hiding, rerouting gas, cutting power, using the environment and deceiving AI are first-class strategies.
2. **No magic puzzle solutions.** Authors define physical/logical goals. Any solution that satisfies constraints may work, including solutions the author did not anticipate.
3. **Scarcity is structural.** Maintenance tools have real head types, consumables and tolerances. Finding a Robertson screwdriver three decks away can be meaningful because the player previously catalogued an unopened panel, not because a quest marker prescribed it.
4. **Consequences persist.** Burnt wires stay burnt; bypassed interlocks stay bypassed; a broken pump raises pressure elsewhere; a borrowed fuse cannot simultaneously serve two machines.
5. **Complexity is learnable.** Expert-level electronics and control systems are encouraged, but the station must provide schematics, part markings, meter measurements, diagnostics, field manuals, maintenance logs and opportunities to experiment.
6. **The AI is a systems adversary.** It has sensors, imperfect information, capabilities and resource costs. It can flood compartments with inert gas, switch lighting, lock bulkheads or manipulate maintenance telemetry, but not teleport, ignore power, or secretly cheat puzzle rules.
7. **The game does not demand combat.** A character who "walks forward and shoots" should run out of ammunition and options; a careful engineer finds physical bypasses and system-level leverage.
8. **Backtracking is a strategic consequence.** Repairs require preparations, risk, and transport; every return trip can reveal changes made by damaged station systems or AI adaptation.

## Three incompatible power domains

These are starting concepts, not yet physically complete implementations:

| Domain | Engineering role | Possible complications |
|---|---|---|
| 48 V DC service bus | low-voltage logic, robotics interfaces, actuators | sag, grounding, short circuits, corroded contacts, batteries |
| 400 Hz AC industrial bus | pumps, compressor drives, legacy equipment | isolation, transformers, phase/frequency, relay timing |
| pulsed high-voltage distribution | beam optics, energy storage, pulsed machinery | charging interlocks, capacitor banks, surge damage, timing |

Interoperability requires explicit converters or intermediate systems. An AC-powered motor cannot be run by tapping a DC logic rail. A pulse supply cannot be safely reused as an ordinary continuous voltage. Convertors can fail, overload, heat up, and consume scarce spares. Every subsystem should expose **what powers it, what it powers, what can switch it off, and how it behaves after a fault**.

## Layers of station simulation

- **Physical:** electrical circuits, thermal control, fluid pressure, atmosphere, radiation, mechanical damage, cable routing.
- **Automation:** sensors, PLC-style sequencing, feedback control, deadlines, redundant interlocks.
- **Digital:** permissions, protocols, logging, authentication, topology, station AI intrusion.
- **Mechanical:** fasteners, alignment, springs, belts, bearings, consumables, improvised mounting.
- **Logistics:** tool ownership, stock, salvage grades, storage, transport and fabrication.
- **Narrative:** readable inspection clues; the player reconstructs what the station is, why the systems interact, and what the AI is doing.

Complexity is allowed to exceed what is strictly required; hidden layers must nonetheless obey a coherent causal model.

## Puzzle families beyond electronics

- Stabilize cooling loops by repairing valves, pumps and sensors rather than merely "turning fans on."
- Debug a security protocol by observing challenge/response and manipulating network timing.
- Reassemble robot servo drive hardware with compatible gears and improvised voltage regulation.
- Reroute fire suppression, atmosphere and pressure zones without killing bystanders.
- Open a mechanically jammed bulkhead by unloading its hydraulic circuit and defeating its lockout procedure.
- Maintain communication during an outage by supplying power, clock synchronization and a valid access role.
- Infiltrate a sealed area by altering its telemetry rather than defeating its guards.

Puzzle goals are **states** with tolerances and time constraints, not strict item-use sequences.

## A canonical door problem

The door has a 48V motor drive, an interlock powered by the industrial bus through a converter, a protocol check with a station security controller, a manual override that requires a particular screwdriver, and a burned relay driver. Repairing the relay does not necessarily grant permission. Hacking the protocol does not repair the power train. The player might mechanically unlatch it using equipment borrowed from another deck, at the cost of later making an airlock unsafe.

**The surprise is not a random twist.** It is discovering, repeatedly, that the station behaves like a real, intricately interconnected place.

## Difficulty and fairness

The electrical game should support undergraduate-level reasoning: Kirchhoff's laws, resistor networks, semiconductors, thermal limits, current paths and failure modes. The player must be able to inspect pinouts and voltages, instrument the system, and observe damaged parts. Provide optional in-world service manuals, not simplified mandatory tutorials. Do not simulate nanosecond semiconductor behavior when the player has no tools to diagnose it.

Information is scarce, not arbitrarily withheld. A difficult system has multiple independent clues, consistent test results, and plausible physical behavior.
