// Offline characterization only. The app and Xcode tests never load the LongRange checkout.
// Run from First Round's repository root:
//   node Reference/generate-wind-references.mjs /path/to/LongRange
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

const root = process.argv[2];
if (!root) throw new Error('Pass the pinned LongRange checkout path.');
const enginePath = resolve(root, 'GameBuild/engine/build-wasm/ballistics_toolkit_wasm.js');
const { default: factory } = await import(pathToFileURL(enginePath).href);
const module = await factory();
const seed = 1337;
const clockS = 30;
const bounds = { min: { x: -30, y: 0, z: -1000 }, max: { x: 30, y: 50, z: 0 } };
const vec = p => new module.Vector3D(p.x, p.y, p.z);
const toPlain = v => ({ x: v.x, y: v.y, z: v.z });

function newField() {
  module.Random.seed(seed);
  const min = vec(bounds.min), max = vec(bounds.max);
  const field = module.WindPresets.getPreset('Moderate', min, max);
  min.delete(); max.delete();
  field.advanceTime(clockS);
  return field;
}
function sampleRows(trajectory, ranges) {
  return ranges.map(rangeM => {
    const point = trajectory.atDistance(rangeM);
    if (!point) throw new Error(`reference trajectory misses ${rangeM} m`);
    const state = point.getState();
    const pos = state.getPosition();
    const row = { rangeM, dropM: pos.y, windageM: pos.x, velocityMps: point.getVelocity(), timeOfFlightS: point.getTime() };
    pos.delete(); state.delete(); point.delete();
    return row;
  });
}

// The Moderate gust field is zero-mean. Keep a distinct nonzero mean vector and
// explicitly add it to each field sample during the reference shot.
const meanWind = { x: 1.5, y: 0, z: -0.25 };
const field = newField();
const samplePoints = [
  { x: 0, y: 1.6, z: 0, timeS: clockS },
  { x: 0, y: 1.6, z: -100, timeS: clockS },
  { x: 5, y: 2, z: -300, timeS: clockS },
  { x: -12, y: 10, z: -750, timeS: clockS },
];
const expectedWind = samplePoints.map(p => {
  const v = field.sample(p.x, p.y, p.z);
  const out = toPlain(v); v.delete();
  return { position: { x: p.x, y: p.y, z: p.z }, timeS: p.timeS, gustMps: out,
    totalWindMps: { x: out.x + meanWind.x, y: out.y + meanWind.y, z: out.z + meanWind.z } };
});
const load = { massKg: 0.0090718474, diameterM: 0.0067056, lengthM: 0.0353568,
  bc: 0.326, dragModel: 'G7', muzzleVelocityMps: 826.008, twistM: 0.2032 };
const atmosphereInput = { temperatureK: 288.15, altitudeM: 0, humidity: 0.5, pressurePa: 0 };
const bullet = new module.Bullet(load.massKg, load.diameterM, load.lengthM, load.bc, module.DragFunction.G7);
const atmosphere = new module.Atmosphere(atmosphereInput.temperatureK, atmosphereInput.altitudeM,
  atmosphereInput.humidity, atmosphereInput.pressurePa);
const zeroWind = vec({ x: 0, y: 0, z: 0 });
const target = vec({ x: 0, y: 0, z: -100 });
const simulator = new module.BallisticsSimulator();
simulator.setInitialBullet(bullet); simulator.setAtmosphere(atmosphere); simulator.setWind(zeroWind);
simulator.computeZero(load.muzzleVelocityMps, target, 0.001, 50, 1e-5, (2 * Math.PI * load.muzzleVelocityMps) / 0.2032).delete();
simulator.setWind(vec(meanWind));
const start = simulator.getInitialBullet();
const generatedSim = new module.BallisticsSimulator();
generatedSim.setInitialBullet(start); generatedSim.setAtmosphere(atmosphere);
const gustAtMuzzle = field.sample(0, 0, 0); const initialWind = vec({ x: gustAtMuzzle.x + meanWind.x, y: meanWind.y,
  z: gustAtMuzzle.z + meanWind.z });
generatedSim.setWind(initialWind);
// Append the zeroed launch state, then reproduce simulateWithWind's sampler /
// timeStep ordering while superposing the selected mean vector.
generatedSim.simulate(0, 0.001, 0);
const trajectory = generatedSim.getTrajectory();
let t = 0;
const endM = 600 * 1.05;
function currentPosition(sim) {
  const bulletState = sim.getCurrentBullet();
  const position = bulletState.getPosition();
  const out = toPlain(position);
  position.delete(); bulletState.delete();
  return out;
}
while (t < 15 && -currentPosition(generatedSim).z <= endM) {
  const current = generatedSim.getCurrentBullet();
  const pos = current.getPosition();
  const gust = field.sample(pos.x, pos.y, pos.z);
  const wind = vec({ x: gust.x + meanWind.x, y: gust.y + meanWind.y, z: gust.z + meanWind.z });
  generatedSim.setWind(wind);
  generatedSim.timeStep(0.001);
  pos.delete(); current.delete(); gust.delete(); wind.delete();
  t += 0.001;
}
const windRows = sampleRows(trajectory, [100, 300, 600]);

// Current web shot mode: zero in calm air, then fly with a constant live wind.
module.Random.seed(20260924);
const webBullet = new module.Bullet(load.massKg, load.diameterM, load.lengthM, load.bc, module.DragFunction.G7);
const webSim = new module.BallisticsSimulator();
webSim.setInitialBullet(webBullet); webSim.setAtmosphere(atmosphere); webSim.setWind(zeroWind);
webSim.computeZero(load.muzzleVelocityMps, target, 0.001, 50, 1e-5,
  (2 * Math.PI * load.muzzleVelocityMps) / 0.2032).delete();
const liveWind = vec({ x: 4.4704, y: 0, z: 0 }); webSim.setWind(liveWind);
webSim.simulate(600 * 1.05, 0.001, 30);
const webTrajectory = webSim.getTrajectory();
const webRows = sampleRows(webTrajectory, [100, 300, 600]);

const source = { sourceRevision: 'a96c8f67ed2f395d111b1da5613f151823f7742c',
  generator: 'Reference/generate-wind-references.mjs; Emscripten 6.0.9 owned-engine WebAssembly artifact',
  seed, preset: 'Moderate', fieldClockS: clockS, fieldBoundsM: bounds, meanWindMps: meanWind,
  samples: expectedWind, trajectory: { load, atmosphere: atmosphereInput, zeroRangeM: 100, stepS: 0.001, meanWindMps: meanWind, rows: windRows },
  randomNote: 'The engine uses std::mt19937 and Emscripten 6.0.9 libc++ shuffle/uniform distributions. Swift ports libc++ shuffle ordering, low-bit mask/rejection bounded draws, and float generate_canonical; captured sample tests verify the sequence.' };
const web = { sourceRevision: 'a96c8f67ed2f395d111b1da5613f151823f7742c',
  generator: 'Reference/generate-wind-references.mjs; solve sequence mirrors GameBuild/app/src/engine-bridge/index.ts',
  load, atmosphere: atmosphereInput, zeroMode: 'calmAir', zeroRangeM: 100, sightHeightM: 0,
  liveWindMps: { x: 4.4704, y: 0, z: 0 }, sampleRangesM: [100, 300, 600], rows: webRows };
writeFileSync('Reference/Fixtures/generated-wind.json', JSON.stringify(source, null, 2) + '\n');
writeFileSync('Reference/Fixtures/web-shot.json', JSON.stringify(web, null, 2) + '\n');
for (const h of [bullet, atmosphere, zeroWind, target, simulator, start, generatedSim, webBullet, webSim, liveWind, field]) h.delete();
console.log('Wrote generated-wind.json and web-shot.json from ' + enginePath);
