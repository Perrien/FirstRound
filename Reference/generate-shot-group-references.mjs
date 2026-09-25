// Offline characterization only. App code and tests never call the legacy engine.
// Run from this repository root: node Reference/generate-shot-group-references.mjs /path/to/LongRange
import { createHash } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const root = process.argv[2];
if (!root) throw new Error('Pass the pinned LongRange checkout path.');
const revision = 'a96c8f67ed2f395d111b1da5613f151823f7742c';
const enginePath = resolve(root, 'GameBuild/engine/build-wasm/ballistics_toolkit_wasm.js');
const factory = (await import(pathToFileURL(enginePath).href)).default;
const module = await factory();

const load = { massKg: 140 * 0.00006479891, diameterM: 0.264 * 0.0254,
  lengthM: 1.392 * 0.0254, bc: 0.326, dragModel: 'G7', muzzleVelocityMps: 2710 * 0.3048,
  twistM: 8 * 0.0254 };
const atmosphere = { temperatureK: 288.15, altitudeM: 0, humidity: 0.5, pressurePa: 0 };
const rangeM = 274.32;
const radPerMOA = Math.PI / (180 * 60);
const cases = [
  { id: 'match-50-seed-12345', count: 50, seed: 12345, mvSdMps: 2.7, bcSdFraction: 0.005,
    rifleConeDiameterRad: 0.5 * radPerMOA, scopeCantLimitRad: 0, crosswindSdMps: 0, headwindSdMps: 0, updraftSdMps: 0 },
  { id: 'bulk-50-seed-12345', count: 50, seed: 12345, mvSdMps: 5.2, bcSdFraction: 0.015,
    rifleConeDiameterRad: 1.5 * radPerMOA, scopeCantLimitRad: 0, crosswindSdMps: 0, headwindSdMps: 0, updraftSdMps: 0 },
  { id: 'wind-50-seed-12345', count: 50, seed: 12345, mvSdMps: 2.7, bcSdFraction: 0.005,
    rifleConeDiameterRad: 0.5 * radPerMOA, scopeCantLimitRad: 0, crosswindSdMps: 0.75, headwindSdMps: 0.35, updraftSdMps: 0.2 },
];

function run(config) {
  module.Random.seed(config.seed);
  const bullet = new module.Bullet(load.massKg, load.diameterM, load.lengthM, load.bc, module.DragFunction.G7);
  const atmos = new module.Atmosphere(atmosphere.temperatureK, atmosphere.altitudeM, atmosphere.humidity, atmosphere.pressurePa);
  const target = new module.Target('dummy', 1000, 1000, 1000, 1000, 1000, 1000, 1000, 'ignored');
  const sim = new module.MatchSimulator(bullet, load.muzzleVelocityMps, target, rangeM, atmos,
    config.mvSdMps, config.bcSdFraction, config.crosswindSdMps, config.headwindSdMps,
    config.updraftSdMps, config.rifleConeDiameterRad, config.scopeCantLimitRad, 0.001, load.twistM);
  bullet.delete(); atmos.delete(); target.delete();
  const shots = [];
  for (let i = 0; i < config.count; i++) {
    const s = sim.fireShot();
    shots.push({ index: i + 1, xM: s.impactX, yM: s.impactY, mvMps: s.actualMv, bc: s.actualBc,
      releaseAngleHMrad: s.releaseAngleH, releaseAngleVMrad: s.releaseAngleV,
      cantRad: s.scopeCant, crosswindMps: s.windCrossrange, headwindMps: s.windDownrange,
      updraftMps: s.windVertical });
  }
  const match = sim.getMatch();
  const legacy = { rmsDistanceFromAimOriginM: match.getMeanRadius(), boundingBoxDiagonalM: match.getGroupSize() };
  const center = shots.reduce((sum, shot) => ({ x: sum.x + shot.xM / shots.length, y: sum.y + shot.yM / shots.length }), { x: 0, y: 0 });
  const result = { ...config, shots, centerFromAimM: center, legacyMetrics: legacy };
  match.delete(); sim.delete();
  return result;
}

const payload = { sourceRevision: revision,
  generator: 'Reference/generate-shot-group-references.mjs; Emscripten 6.0.9 owned-engine WebAssembly artifact',
  load, atmosphere, rangeM, zero: { timestepS: 0.001, maxIterations: 1000, toleranceM: 1e-6, maxTimeS: 30 },
  normalClippingSigma: 3, coordinateNote: '+x right, +y up, -z downrange; impacts are scatter about the deterministic aim center.',
  cases: cases.map(run) };
const canonical = JSON.stringify(payload);
const sha256 = createHash('sha256').update(canonical).digest('hex');
writeFileSync('Reference/Fixtures/shot-group.json', JSON.stringify({ ...payload, sha256 }, null, 2) + '\n');
console.log(`Wrote Reference/Fixtures/shot-group.json (${sha256}) from ${enginePath}`);
