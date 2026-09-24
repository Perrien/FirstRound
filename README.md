# First Round

A native long-range shooting simulation for macOS and iOS. The player reads the environment, builds a firing solution, then sees whether the shot connects.

This is a new Swift project with its own Git history. The older `LongRange` repository remains a playable web reference and a source for fixed physics comparison cases. First Round must build, test, and run without the old repository present.

## Project map

- `Xcode Build/First Round.xcodeproj` — the owner-created multiplatform Xcode project, targeting macOS 27 and iOS 27.
- `LADDER.md` — the eight native outcomes in order.
- `Plans/` — one active, focused implementation plan at a time. Completed plans, including `Native-Foundation.md`, are in `Plans/Archived/`.
- `Reference/Fixtures/` — fixed expected results for automated tests, with provenance in `Reference/README.md`. The app never displays fixture answers; the planned solver will calculate trajectories from current inputs.

The app target is named `First Round` with bundle identifier `com.digitalenki.FirstRound`. The `First RoundTests` target checks bundled reference fixtures, vector and quaternion math, and exact unit conversions on macOS and iOS. The app has an editable measurement preview that converts box values to SI as they are entered. The trajectory solver is the next milestone.
