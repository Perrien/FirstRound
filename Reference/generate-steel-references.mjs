// Offline characterization only. App code and tests never call the legacy engine.
// Run from this repository root: node Reference/generate-steel-references.mjs /path/to/LongRange
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

const thicknessM = 0.0127;
const centerM = { x: 0, y: 2, z: -100 };
const bulletMassKg = 140 * 0.00006479891;
const bulletDiameterM = 0.264 * 0.0254;
const incomingVelocityMps = { x: 0, y: 0, z: -700 };
const timesS = [0, 0.02, 0.2, 1];
const cases = [
  { id: 'center-6in', diameterM: 0.1524, impactOffsetM: { x: 0, y: 0 } },
  { id: 'right-rim-6in', diameterM: 0.1524, impactOffsetM: { x: 0.45 * 0.1524, y: 0 } },
  { id: 'left-rim-6in', diameterM: 0.1524, impactOffsetM: { x: -0.45 * 0.1524, y: 0 } },
  { id: 'hard-off-center-2in', diameterM: 0.0508, impactOffsetM: { x: 0.45 * 0.0508, y: 0 } },
  { id: 'hard-off-center-12in', diameterM: 0.3048, impactOffsetM: { x: 0.45 * 0.3048, y: 0 } },
];

function vector(value) { return new module.Vector3D(value.x, value.y, value.z); }
function plainVec(value) {
  const result = { x: value.x, y: value.y, z: value.z };
  value.delete();
  return result;
}
function snapshot(target, elapsedS) {
  const position = plainVec(target.getCenterOfMass());
  const normal = plainVec(target.getNormal());
  const angularVelocity = plainVec(target.getAngularVelocity());
  const quaternion = target.getOrientation();
  const orientation = { w: quaternion.w, x: quaternion.x, y: quaternion.y, z: quaternion.z };
  quaternion.delete();
  return { elapsedS, centerOfMassM: position, normal, orientation, angularVelocityRadPerSecond: angularVelocity,
    isMoving: target.isMoving() };
}

function run(config) {
  const center = vector(centerM);
  const normal = vector({ x: 0, y: 0, z: -1 });
  const target = new module.SteelTarget(config.diameterM, config.diameterM, thicknessM, true, center, normal, 32);
  const radius = config.diameterM * 0.5;
  const ax = radius * Math.sin(0.6);
  const ay = radius * Math.cos(0.6);
  const beamHeightM = centerM.y + ay + 0.5;
  for (const side of [-1, 1]) {
    const local = vector({ x: side * ax, y: ay, z: -thicknessM * 0.5 });
    const world = vector({ x: centerM.x + side * ax, y: centerM.y + ay, z: centerM.z - thicknessM * 0.5 });
    const fixed = vector({ x: world.x - side * 0.05, y: beamHeightM, z: world.z });
    target.addChainAnchor(local, fixed);
    local.delete(); world.delete(); fixed.delete();
  }

  const impactPointM = { x: centerM.x + config.impactOffsetM.x, y: centerM.y + config.impactOffsetM.y, z: centerM.z };
  const base = new module.Bullet(bulletMassKg, bulletDiameterM, 1.392 * 0.0254, 0.326, module.DragFunction.G7);
  const point = vector(impactPointM);
  const velocity = vector(incomingVelocityMps);
  const bullet = new module.Bullet(base, point, velocity, 0);
  target.hit(bullet);
  const frames = [snapshot(target, 0)];
  let timeS = 0;
  for (const nextTimeS of timesS.slice(1)) {
    target.timeStep(nextTimeS - timeS);
    timeS = nextTimeS;
    frames.push(snapshot(target, timeS));
  }

  let settleTimeS = null;
  const maxSettleTimeS = 40;
  const stepS = 1 / 60;
  for (let i = 0; i < Math.ceil(maxSettleTimeS / stepS); i++) {
    target.timeStep(stepS);
    timeS += stepS;
    if (!target.isMoving()) {
      settleTimeS = timeS;
      frames.push(snapshot(target, timeS));
      break;
    }
  }

  const result = { ...config, thicknessM, centerM, beamHeightM, bulletMassKg, bulletDiameterM,
    impactPointM, incomingVelocityMps, initialMassKg: target.getMass(), sampledFrames: frames.slice(0, timesS.length),
    settle: settleTimeS === null ? { elapsedS: maxSettleTimeS, didSettle: false } : { elapsedS: settleTimeS, didSettle: true, pose: frames.at(-1) } };
  bullet.delete(); base.delete(); velocity.delete(); point.delete(); target.delete(); center.delete(); normal.delete();
  return result;
}

const payload = { sourceRevision: revision,
  generator: 'Reference/generate-steel-references.mjs; Emscripten 6.0.9 owned-engine WebAssembly artifact',
  physics: { plateShape: 'round ellipse', steelDensityKgPerM3: 7850, thicknessM,
    minMassKg: 2, chainAnchorAngleRad: 0.6, chainLengthM: 0.5, chainOutwardOffsetM: 0.05,
    bullet: '6.5 Creedmoor 140 gr; 0.264 in diameter', incomingSpeedMps: 700,
    outerFrameStepForSettleS: 1 / 60, internalSubstepMaxS: 0.001, settleCapS: 40 },
  coordinates: '+x right, +y up, -z downrange; plate rest normal (0,0,-1).',
  sampleTimesS: [0, 0.02, 0.2, 1],
  cases: cases.map(run) };
const canonical = JSON.stringify(payload);
const sha256 = createHash('sha256').update(canonical).digest('hex');
writeFileSync('Reference/Fixtures/steel-reaction.json', JSON.stringify({ ...payload, sha256 }, null, 2) + '\n');
console.log(`Wrote Reference/Fixtures/steel-reaction.json (${sha256}) from ${enginePath}`);
