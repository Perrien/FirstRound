# First Round

A native long-range shooting simulation for macOS and iOS. The player reads the environment, builds a firing solution, then sees whether the shot connects.

This is a new Swift project with its own Git history. The older `LongRange` repository remains a playable web reference and a source for fixed physics comparison cases. First Round must build, test, and run without the old repository present.

## Current state

The owner created `Xcode Build/First Round.xcodeproj` in this repository with one multiplatform app target named `First Round`. Xcode set iOS 27 and macOS 27 as deployment targets and `com.digitalenki.FirstRound` as its bundle identifier. A test target and the native solver have not been built yet.

`PLAN.md` is the single migration ladder. `Reference/Fixtures/` contains fixed inputs and expected results for tests; the app must calculate trajectories from current inputs rather than display fixture answers.
