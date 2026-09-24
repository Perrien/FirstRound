# First Round

A native long-range shooting simulation for macOS and iOS. The player reads the environment, builds a firing solution, then sees whether the shot connects. Outcome 2 is implemented: the Mac screen calculates trajectories from editable inputs, with constant wind or a repeatable seeded Moderate gust field.

This is a new Swift project with its own Git history. The older `LongRange` repository remains a playable web reference and a source for fixed physics comparison cases. First Round must build, test, and run without the old repository present.

## Project map

- `Xcode Build/First Round.xcodeproj` — the owner-created multiplatform Xcode project, targeting macOS 27 and iOS 27.
- `LADDER.md` — the eight native outcomes in order.
- `Plans/` — one active, focused implementation plan at a time. Completed plans, including `Native-Foundation.md`, are in `Plans/Archived/`.
- `Reference/Fixtures/` — fixed expected results for automated tests, with provenance and regeneration commands in `Reference/README.md`. The app never displays fixture answers.

The app target is named `First Round` with bundle identifier `com.digitalenki.FirstRound`. Its screen offers ten editable cartridge starting loads, atmosphere and zero inputs, mean wind, optional generated gusts, range controls, and a fresh result table. Calculations use SI internally; distance units and MIL/MOA display choices are independent. A calm-air zero is followed by the selected live wind, so the zero-range row can show a small wind displacement.

The `First RoundTests` target checks the unchanged 36-case legacy matrix, generated-wind samples and trajectory rows, current web-shot behavior, solver invariants, vector and quaternion math, and unit conversions. Verification for this milestone is macOS only. The remaining ladder outcomes cover dispersion and steel physics, the playable shot loop, motion aiming, saved rifles and DOPE, truing/catalog gameplay, and a reactive range. The app and tests do not require the LongRange checkout at runtime.
