# First Round migration ladder

Status: **DRAFT** — 2026-09-24. No milestone has started.

This is the single plan for the new Swift app. Work through the milestones below in order, expanding the next milestone into exact tasks and checks here before building it. Do not create plans beneath this plan. The existing web app in `~/Developer/LongRange/` is a read-only behavioral reference during the port; it is not a build or runtime dependency.

## Starting point

- The owner created `Xcode Build/First Round.xcodeproj` in this repository. Its current scheme and app target are `First Round`, with iOS 27 and macOS 27 deployment targets. Preserve the Xcode project and its existing uncommitted edits. The bundle identifier is `com.digitalenki.FirstRound`.
- Use SwiftUI for controls, RealityKit for the range, and a Swift physics core. The app target is multiplatform; platform-specific input code may differ. Use SwiftData for local saves when that milestone arrives.
- The old C++/WASM engine stays in the old repository. Copy fixed test cases here with their provenance. No native source or test may reference a path in `LongRange` at build or run time.
- The player-facing solver uses editable box values and performs a fresh solve. Golden vectors are test inputs only.
- Support both metric and imperial units and both MIL and MOA. Keep hidden true rifle/load values separate from what the player sees. Targets are steel or human silhouettes, with no animals or money economy.

## Milestones

| # | Result | Status |
|---|---|---|
| 1 | Native foundation and fixture reader | not started |
| 2 | Working trajectory solver and inspection screen | not started |
| 3 | Dispersion and steel physics | not started |
| 4 | First playable shot loop | not started |
| 5 | Motion aiming on iOS | not started |
| 6 | Saved rifles, zeroing, and computed DOPE | not started |
| 7 | Simulated chronograph, truing, and gameplay catalog | not started |
| 8 | Reactive practice range and shot feedback | not started |

### 1. Native foundation and fixture reader

Add a `First RoundTests` unit-test target to the existing Xcode project in `Xcode Build/`. Keep the owner-created app target and project name. Implement vector, quaternion, unit conversion, deterministic random, and simplex math helpers in Swift. Load `Reference/Fixtures/loads.json` and `golden.json` through the test target and verify 36 cases and 660 trajectory rows. Check that Mac and iOS app targets build and the tests pass with the old repository unavailable. This milestone does not claim physics parity.

### 2. Working trajectory solver and inspection screen

Port atmosphere, G1/G7 drag, zeroing, point-mass integration, spin drift, trajectory sampling, and constant wind. Compare calculated Swift rows with the committed golden vectors. Record separate reference cases for generated wind and the current web shot sequence, which zeros in calm air and applies live wind afterward; the original vectors do not cover either. Preserve the existing vectors unchanged.

Build a SwiftUI screen that runs the Swift solver. Offer representative defaults from the web game's ten-cartridge catalog, exporting only player-facing values into a small native preset file. Selecting a preset fills editable weight, diameter, length, BC, muzzle velocity, and twist fields. Include editable weather, wind, zero range, sight height, and regular or individually requested target ranges. Show automatic SI equivalents. Calculate fresh rows for range, drop, windage, remaining velocity, flight time, and MIL/MOA corrections. Allow metric and imperial display. Invalid inputs must clear or clearly invalidate prior output. The owner should be able to select the .50 BMG default, see 661 grains and 0.51 inches, edit bullet and weather inputs, and watch the output change on Mac and an iOS simulator.

### 3. Dispersion and steel physics

Port Monte Carlo dispersion and steel-target reaction physics. Add fixed comparison cases exported from the old engine, since `golden.json` does not cover these. Verify the Swift results and edge cases in unit tests.

### 4. First playable shot loop

Build one rifle/load and one target in a simple RealityKit scene. Use touch-drag aiming on iOS and pointer aiming on Mac. Port target-picking behavior, including crosshair and angular-selection edge cases. Dial or hold, fire through the Swift solver, and show hit or miss on both platforms.

### 5. Motion aiming on iOS

Add optional CoreMotion tilt-and-shift aiming, an on-screen recenter control, feedback, and separate motion sensitivity. Keep touch-drag usable when motion data is unavailable. Mac retains pointer aiming.

### 6. Saved rifles, zeroing, and computed DOPE

Use local SwiftData saves for rifle/load profiles. Rebuild the zeroing flow and computed DOPE from player-believed values. Keep simulated hidden truth out of normal readouts. Verify a saved profile survives relaunch and recalculates its DOPE.

### 7. Simulated chronograph, truing, and gameplay catalog

Bring the simulated chronograph into the shot loop, then add muzzle-velocity and BC truing as distinct controls. Make all ten catalog cartridges available in gameplay, separate from the solver screen's starting presets. Verify each can be selected and that truing changes computed DOPE.

### 8. Reactive practice range and shot feedback

Build one practice range with several target distances. Add reactive steel, mirage, impact calls, recoil feedback, and a session shot history with impact position, miss distance, and grouping. Verify the full experience on Mac and iPhone.

## Later work

Add more ranges by transferring their dimensions and behavior deliberately from the web build. Consider cross-device saves and peer-to-peer play separately. The web build remains a playable reference throughout this ladder.
