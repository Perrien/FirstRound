# Fixed reference fixtures

These files were copied from the separate `LongRange` web/oracle repository on 2026-09-24 for native tests. They are not app data and must never supply the solver screen's answers.

| File | Source in LongRange | SHA-256 |
|---|---|---|
| `Fixtures/loads.json` | `GameBuild/validation/loads.json` | `9334e8c4e5afa5e560c48a960237c9ccb0e10f945cb42247aa0eff13fb3af1fe` |
| `Fixtures/golden.json` | `GameBuild/validation/vectors/golden.json` | `c9b40dfb8e91794d093e3a8f9241474a66ab65d059530da277131768cf8b4706` |

The oracle was pristine BallisticsToolkit commit `29d43c13f4945cb9caf4e73d2041c22645ebf4e7`, with no physics patches. `golden.json` contains 36 cases and 660 rows for six loads, three atmospheres, and two constant winds. It is a characterization reference for the original zeroing and trajectory path. It does not cover generated wind fields or the web game's current calm-air-zero-then-live-wind shot sequence; those require separate fixtures.

Keep these files fixed. When adding a new comparison case, document the generator, source revision, inputs, outputs, and reason in this folder. A differing Swift result is investigated rather than concealed by changing the expected value or tolerance.
