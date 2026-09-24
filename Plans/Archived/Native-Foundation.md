# Native foundation and conversion preview

Status: **COMPLETE — final commit checkpoint** · 2026-09-24

Goal: Make the owner-created First Round project testable and show one honest, interactive native result before trajectory physics arrives. A user enters bullet box measurements and immediately sees their SI equivalents. The original golden-vector files remain test-only.

This is milestone 1 of `LADDER.md`. It is a bounded first slice, not a replacement for the ladder or a plan for later milestones. Mark each work item `in progress` or `complete` here as work proceeds; keep this file usable after a stopped session.

## Starting state and constraints

- Repository root: `~/Developer/First Round/`. Xcode project and app sources: `Xcode Build/First Round.xcodeproj` and `Xcode Build/First Round/`. Existing scheme and app target: `First Round`. Deployment targets: iOS 27 and macOS 27. Bundle identifier: `com.digitalenki.FirstRound`. The project currently has no test target.
- `Reference/Fixtures/loads.json` and `Reference/Fixtures/golden.json` are already committed. They are copied from the older `LongRange` repository; `Reference/README.md` records provenance. Do not edit their expected numbers to make a test pass.
- Core math should use `Float` where it mirrors the C++ `float` vector and quaternion operations. The conversion preview may parse into `Double` and must use the exact UI/fixture constants: 1 grain = 0.00006479891 kg, 1 inch = 0.0254 m, 1 foot/second = 0.3048 m/s. Keep conversions in one service rather than in the SwiftUI view.
- No source, test, build script, or runtime code in this repo may require a path inside `LongRange`. Old code can be read as reference while writing the port. Do not copy old `AGENTS.md`, `CLAUDE.md`, process documents, or the C++/WASM source tree.
- The app's current `ContentView.swift` is a Hello World template and imports Playgrounds. This plan replaces it with the conversion preview and removes the template-only playground code. The screen must clearly say it does not yet calculate trajectory, drop, or windage.

## Exact file scope

| File | Action |
|---|---|
| `Xcode Build/First Round.xcodeproj/project.pbxproj` | Add one multiplatform unit-test target named `First RoundTests`; give only that target copies of the two reference JSON files. Keep existing app target, bundle ID, and OS minimums. |
| `Xcode Build/First Round/Math/Vector2D.swift` | Create Float-based 2D vector matching the used C++ operations. |
| `Xcode Build/First Round/Math/Vector3D.swift` | Create Float-based 3D vector matching the used C++ operations. |
| `Xcode Build/First Round/Math/Quaternion.swift` | Create Float-based quaternion operations needed for later orientation and steel physics. |
| `Xcode Build/First Round/Math/UnitConversions.swift` | Create the one unit-conversion service used by UI and tests. |
| `Xcode Build/First Round/ContentView.swift` | Replace template with editable measurement fields and live SI readouts. |
| `Xcode Build/First RoundTests/FixtureReaderTests.swift` | Create test-only JSON fixture loading and matrix-count checks. |
| `Xcode Build/First RoundTests/MathTests.swift` | Create hand-worked vector and quaternion behavior tests. |
| `Xcode Build/First RoundTests/UnitConversionTests.swift` | Create exact-known-value and invalid-input checks for the conversion service. |
| `README.md`, `LADDER.md`, this plan | Update only if the built state or a settled scope choice changes. |

`Reference/Fixtures/loads.json`, `Reference/Fixtures/golden.json`, and `Reference/README.md` are read-only inputs for this plan. Do not add fixtures to the app target.

## Work and review checkpoints

### 1. Test target and fixture reader — complete

Add a native unit-test bundle named `First RoundTests` to the existing Xcode project. The target must run on macOS and an iOS 27 simulator; do not create a second app. Include the two JSON files in the **test target only** as copied bundle resources. In `FixtureReaderTests.swift`, load by bundle resource name rather than an absolute path. Decode enough JSON to assert that `loads.json` has six `loads`, and `golden.json` has 36 `cases` with 660 total `rows`; assert all case `loadId` values exist in `loads.json`, and each row has numeric range, drop, windage, velocity, and flight time. Fail clearly on a missing or malformed file.

**Check:** `xcodebuild -list` shows the test target; macOS tests pass; an available iOS 27 simulator runs the same fixture tests. Confirm the test target loads both files from its own bundle, and search this repository for source or build references to an absolute `LongRange` path. A later clean checkout can repeat the check without the old repository. Show the owner the test summary with the counts; the app still shows Hello World at this checkpoint.

**Commit point:** after this checkpoint passes, show the changed files and test output, then stop before item 2. Suggested message: `Add native test target and bundled reference fixtures`.

### 2. Math helpers and conversion service — complete

Port 2D/3D vector and quaternion arithmetic from the older repository's `GameBuild/engine/include/math/vector.h` and `quaternion.h` into the four Swift files above. Cover constructors/identity, addition and scaling, magnitude, zero-safe normalization, dot, cross, lerp, quaternion multiplication, axis-angle rotation, conjugate, and slerp. Use ordinary Swift value types and `Float`; preserve sign conventions. Tests must include `(3,4)` magnitude 5, normalization of zero, `(1,0,0) × (0,1,0) = (0,0,1)`, identity rotation, and a 90-degree axis-angle rotation. Add only operations with known consumers or present in this list; leave random and noise for milestone 2.

In `UnitConversions.swift`, put named pure functions for grains→kilograms, inches→meters, feet/second→meters/second, and inches/turn→meters/turn. Reject or return no result for empty, nonnumeric, nonfinite, zero, or negative bullet measurements; the UI must not display stale SI values for them. Tests include 300 gr = 0.019439673 kg, 1.68 in = 0.042672 m, and 2725 ft/s = 830.58 m/s, with stated numeric tolerances.

**Check:** all math and conversion tests pass on macOS and iOS. Compare vector/quaternion signs with the old C++ implementation, and verify conversions against hand calculations rather than merely calling the same function in both sides of a test.

**Commit point:** show the test output and changed helpers, then stop before item 3. Suggested message: `Port foundation math and exact unit conversions`.

### 3. Editable conversion preview — complete

Replace `ContentView.swift` with a simple SwiftUI form titled **First Round — Measurement Preview**. Provide text fields for bullet weight (grains), diameter (inches), length (inches), muzzle velocity (feet/second), and twist (inches per turn). Start with empty fields and example placeholders; do not read `loads.json` or `golden.json` in app code. Each valid field immediately shows its SI equivalent beside or below it. Blank fields show `—`; nonnumeric, nonfinite, zero, and negative entries show `—` plus a brief field-level hint, without leaving the prior converted value visible. Keep text editing usable on both Mac and iPhone; show kilograms and meters to eight decimal places and meters/second to two decimal places, always with unit labels. State on screen: “Trajectory calculations arrive in the next milestone.”

**User check:** on Mac and an iOS simulator, enter 300 grains, 0.338 inches, 1.68 inches, 2725 feet/second, and 10 inches/turn; see about 0.01944 kg, 0.0085852 m, 0.042672 m, 830.58 m/s, and 0.254 m/turn. Change 300 to 661 and see mass update to about 0.04283208 kg; clear or invalidate a field and see its SI result clear. No trajectory table or fixture answer appears.

**Build check:** app builds for generic macOS and iOS Simulator; tests remain green on both. Show a screenshot or live screen plus the test summary to the owner.

**Commit point:** show the working preview and checks, then stop. Suggested message: `Add editable box-to-SI preview`.

## Verification commands

Run from `~/Developer/First Round/` (quote paths with spaces). Use a temporary derived-data directory, such as `/private/tmp/FirstRoundDerivedData`, and `CODE_SIGNING_ALLOWED=NO` for command-line checks. The existing scheme is `First Round`.

```bash
xcodebuild -project 'Xcode Build/First Round.xcodeproj' -scheme 'First Round' -destination 'platform=macOS' -derivedDataPath /private/tmp/FirstRoundDerivedData CODE_SIGNING_ALLOWED=NO test
xcodebuild -project 'Xcode Build/First Round.xcodeproj' -scheme 'First Round' -destination 'generic/platform=macOS' -derivedDataPath /private/tmp/FirstRoundDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project 'Xcode Build/First Round.xcodeproj' -scheme 'First Round' -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/FirstRoundDerivedData CODE_SIGNING_ALLOWED=NO build
```

List available iOS 27 simulators with `xcrun simctl list devices available`, then run the same `test` command with `-destination 'platform=iOS Simulator,id=<available-device-UDID>'`. Do not treat a generic iOS build as a substitute for iOS tests. The fixture tests must load their own bundle resources when the old repository is absent.

## Boundaries and stop conditions

- No trajectory solver, drop/windage table, catalog presets, generated wind, random, simplex noise, save system, or RealityKit range in this plan. They belong to later outcomes in `LADDER.md`.
- Do not put golden vectors in the app bundle or use them as UI answers. Do not alter their values or loosen a failing test to claim success.
- Stop and explain options if Xcode cannot make one test target run on both platforms, if copying fixtures into the test bundle fails, if the old source contains a math behavior that cannot be carried into Swift without choosing new semantics, or if verification differs from the stated hand-worked results. Do not silently redesign the project.
- At each commit point, stop for the owner to commit or to ask for the named commit. Do not modify the next item until the owner says to proceed. Do not push or rewrite Git history without an explicit request.
- On completion, update the first outcome in `LADDER.md` to complete and the README's current state, then move this file to `Plans/Archived/` without renaming it. The next plan should cover only the next useful landmark.
