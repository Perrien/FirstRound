# Fixed reference fixtures

These files were copied from the separate `LongRange` web/oracle repository on 2026-09-24 for native tests. They are not app data and must never supply the solver screen's answers.

| File | Source in LongRange | SHA-256 |
|---|---|---|
| `Fixtures/loads.json` | `GameBuild/validation/loads.json` | `9334e8c4e5afa5e560c48a960237c9ccb0e10f945cb42247aa0eff13fb3af1fe` |
| `Fixtures/golden.json` | `GameBuild/validation/vectors/golden.json` | `c9b40dfb8e91794d093e3a8f9241474a66ab65d059530da277131768cf8b4706` |

The oracle was pristine BallisticsToolkit commit `29d43c13f4945cb9caf4e73d2041c22645ebf4e7`, with no physics patches. `golden.json` contains 36 cases and 660 rows for six loads, three atmospheres, and two constant winds. It is a characterization reference for the original zeroing and trajectory path. It does not cover generated wind fields or the web game's current calm-air-zero-then-live-wind shot sequence; those require separate fixtures.

Keep these files fixed. When adding a new comparison case, document the generator, source revision, inputs, outputs, and reason in this folder. A differing Swift result is investigated rather than concealed by changing the expected value or tolerance.

## Generated wind and current web-shot references

Captured from the owned LongRange engine at revision `a96c8f67ed2f395d111b1da5613f151823f7742c` (the checked-out `HEAD`). These files are distinct from the historical matrix above. `generated-wind.json` pins the seeded `Moderate` field, including its zero-mean gust samples, separately stated mean wind, and trajectory rows with that mean added to each gust sample. `web-shot.json` pins the current calm-air-zero / live-constant-wind path at the zero range and beyond. Neither is app input data.

Exact local generation commands, run with the LongRange submodules/resources already present:

```sh
cd /Users/perrien/Developer/LongRange
emmake make -C GameBuild/engine/build-wasm -j2
cd "/Users/perrien/Developer/First Round"
node Reference/generate-wind-references.mjs "/Users/perrien/Developer/LongRange"
shasum -a 256 Reference/Fixtures/generated-wind.json Reference/Fixtures/web-shot.json
```

The helper uses the built single-file WebAssembly artifact, not Swift. It seeds `Random` before field creation, advances the field to 30 s, and records samples at four fixed positions. For field-shot rows it follows the engine's zeroed launch state and `timeStep` ordering, adding the selected mean vector to each `WindGenerator` sample. The separate web-shot case uses the bridge's calm-zero / live-wind solve order. The field case uses the first golden load, ISA sea-level atmosphere, 100 m zero, 1 ms step and rows at 100, 300, and 600 m.

| File | Source revision | SHA-256 |
|---|---|---|
| `Fixtures/generated-wind.json` | `a96c8f67ed2f395d111b1da5613f151823f7742c` | `003cc2b6d48975130e77b92c76d5cfa8676a516c6e7e84cab3cdc788a9c8cca9` |
| `Fixtures/web-shot.json` | `a96c8f67ed2f395d111b1da5613f151823f7742c` | `f57b7a68b07e90799e84c061ad51add7a20574afd50f69550ec61e10199856eb` |

The engine uses `std::mt19937` plus Emscripten 6.0.9 libc++ distributions. Swift ports the same MT19937 sequence, forward `std::shuffle` order, bounded-integer low-bit mask/rejection draws, and `generate_canonical<float>` conversion. `WindReferenceTests` checks captured samples and rows with the fixtures bundled only in the test target.

## Shot-group references

`Fixtures/shot-group.json` captures three 50-shot groups from the owned LongRange engine at revision `a96c8f67ed2f395d111b1da5613f151823f7742c`: the 6.5 Creedmoor 140 gr match dispersion case, a higher-dispersion case, and a case with independent crosswind, headwind, and updraft variance. The fixture includes ordered per-shot impact offsets, sampled muzzle velocity and BC, release/cant/wind draws, the group center, and the old engine's RMS-from-aim and bounding-box-diagonal values under explicit definitions. Its SHA-256 is over the canonical JSON payload before the `sha256` field is added.

| File | Source revision | Canonical payload SHA-256 | File SHA-256 |
|---|---|---|---|
| `Fixtures/shot-group.json` | `a96c8f67ed2f395d111b1da5613f151823f7742c` | `a3b5e53cda12f47ed97bc080d0d3e863e55683b382d981cf69740eeafcc1d3e4` | `9a88b6c1ecbeaac79cbdf5523d643539552761c655da39ee1be09b3de2814694` |

| File | Source revision | Canonical payload SHA-256 | File SHA-256 |
|---|---|---|---|
| `Fixtures/shot-group.json` | `a96c8f67ed2f395d111b1da5613f151823f7742c` | `a3b5e53cda12f47ed97bc080d0d3e863e55683b382d981cf69740eeafcc1d3e4` | `9a88b6c1ecbeaac79cbdf5523d643539552761c655da39ee1be09b3de2814694` |

Regenerate offline from the First Round repository root when the LongRange checkout has the pinned WASM artifact:

```sh
node Reference/generate-shot-group-references.mjs "/Users/perrien/Developer/LongRange"
shasum -a 256 Reference/Fixtures/shot-group.json
```

The generator is a development tool only. Xcode bundles this JSON only with the test target; the app screen always computes its group from current editable inputs.
