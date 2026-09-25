# First Round migration ladder

Status: active project map · 2026-09-24

This is the ordered list of outcomes for the native app. It is not an execution plan. One focused plan at a time lives in `Plans/`; completed plans move to `Plans/Archived/`. The older `LongRange` web build remains a playable reference and an offline source of comparison data, never a native build or runtime dependency.

| # | Outcome | State |
|---|---|---|
| 1 | Native math, fixture reader, and editable unit conversion preview | complete |
| 2 | Working trajectory solver and inspection screen | complete |
| 3 | Shot-group dispersion and steel physics, with a Mac inspection screen | planned |
| 4 | First playable shot loop | later |
| 5 | Motion aiming on iOS | later |
| 6 | Saved rifles, zeroing, and computed DOPE | later |
| 7 | Simulated chronograph, truing, and gameplay catalog | later |
| 8 | Reactive practice range and shot feedback | later |

## What each outcome means

1. The Xcode project gains a unit-test target. Fixed vectors load only in tests. Swift vector, quaternion, and conversion helpers work. An editable screen shows box measurements converted to SI without claiming to calculate a trajectory.
2. Port atmosphere, G1/G7 drag, zeroing, trajectory integration, spin drift, and wind into Swift. The Mac solver screen calculates fresh rows at intervals or specified ranges from editable inputs, with metric/imperial and MIL/MOA output. Offer editable starting values for all ten game cartridges. Constant mean wind and the seeded Moderate gust field are supported, with separate references for generated wind and the calm-zero/live-wind web shot sequence. iPhone verification remains for a later milestone.
3. Port per-shot dispersion and steel-target reaction physics, with fixed comparison cases and edge tests. The Mac screen lets the owner choose a shot count and seed, run a simulated group, inspect every impact on a plotted target, and read honestly named spread and hit statistics. It also shows center-versus-edge steel reactions. This is an inspectable simulation, before the playable shot loop in outcome 4.
4. Build one rifle/load and one target in RealityKit. Dial or hold, aim by touch on iOS or pointer on Mac, fire, and see hit or miss.
5. Add optional CoreMotion aiming with recenter and sensitivity controls; retain touch and pointer aiming.
6. Save rifles and loads locally, rebuild zeroing and computed DOPE, and preserve the distinction between player-believed values and hidden truth.
7. Add a simulated chronograph, muzzle-velocity and BC truing, and the ten-cartridge gameplay catalog.
8. Build one reactive-steel practice range with mirage, feedback, and session shot history.

Further ranges, cross-device saves, and peer-to-peer play come after this ladder. The native app must build, test, and run without the `LongRange` repository present.
