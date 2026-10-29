// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const vm = require('node:vm'), assert = require('node:assert/strict'), cp = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const config = fs.readFileSync(root + '/ShellConfig.js', 'utf8');
const model = vm.createContext({});
vm.runInContext(config.replace(/^\.pragma library\s*/, ''), model);
for (const preset of ['Linear', 'InOutSine', 'OutBack', 'OutBounce', 'InQuart', 'invalid']) {
  model.barAnimationPreset = preset;
  assert.equal(model.motionPreset(false), preset === 'invalid' ? 'InOutSine' : preset);
  assert.equal(model.motionPreset(true), ['Linear', 'OutBounce', 'InQuart'].includes(preset) ? preset : 'InOutSine');
}
for (const [value, expected] of [[-2,0], [100,3], [NaN,1.70158], [1,1]]) {
  model.animationOvershoot = value; assert.equal(model.motionOvershoot(), expected);
}
for (const [speed, expected] of [[1,600], [2,300], [0.5,1200], [0,600], [-1,600], [Infinity,600], [NaN,600], [100,60], [0.001,6000]]) {
  model.animationSpeed = speed;
  assert.equal(model.motionDuration(600), expected);
}
for (const preset of ['Linear', 'InOutSine', 'OutBack', 'OutBounce', 'InQuart']) {
  model.barAnimationPreset = preset;
  assert.ok(Math.abs(model.motionProgress(0, false)) < 1e-10);
  assert.ok(Math.abs(model.motionProgress(1, false) - 1) < 1e-10);
  if (preset === 'InOutSine') { assert.ok(model.motionProgress(.1, false) < .03); assert.ok(model.motionProgress(.9, false) > .97); }
  if (preset === 'OutBack') assert.ok(model.motionProgress(.8, false) > 1);
}
model.barAnimationPreset = 'OutBounce';
assert.ok(model.motionProgress(1 / 2.75, false) > .999);
assert.equal(model.motionProgress(1.5 / 2.75, false), .75);
for (let i = 0; i <= 1000; i++) {
  const value = model.motionProgress(i / 1000, true);
  assert.ok(value >= 0 && value <= 1);
}
const runner = '/usr/lib/qt6/bin/qmltestrunner';
if (!fs.existsSync(runner)) { console.log('Preset validation passed; Qt sampling skipped (qmltestrunner unavailable).'); process.exit(0); }
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'jeebis-motion-test-'));
try {
  const component = fs.readFileSync(root + '/motion/JeebisNumberAnimation.qml', 'utf8');
  fs.writeFileSync(dir + '/JeebisNumberAnimation.qml', component.replace('../ShellConfig.js', 'ShellConfig.js'));
  for (const name of ['JeebisColorAnimation.qml', 'JeebisRotationAnimation.qml', 'JeebisRotationAnimator.qml']) {
    fs.writeFileSync(dir + '/' + name, fs.readFileSync(root + '/motion/' + name, 'utf8').replace('../ShellConfig.js', 'ShellConfig.js'));
  }
  for (const preset of ['Linear', 'InOutSine', 'OutBack', 'OutBounce', 'InQuart']) {
    fs.writeFileSync(dir + '/ShellConfig.js', config.replace(/var animationSpeed = [^;]+;/, "var animationSpeed = 2;").replace(/var barAnimationPreset = "[^"]*";/, `var barAnimationPreset = "${preset}";`));
    fs.writeFileSync(dir + '/tst_motion.qml', `import QtQuick
import QtTest
TestCase {
  id: testCase
  name: "Motion_${preset}"
  property real value: 0
  property real boundedValue: 0
  property color tint: "#000000"
  property real angle: 0
  Item { id: rotor }
  JeebisColorAnimation { id: colorMotion; target: testCase; property: "tint"; from: "#000000"; to: "#ffffff"; baseDuration: 600 }
  JeebisRotationAnimation { id: rotationMotion; target: testCase; property: "angle"; from: 0; to: 360; baseDuration: 600 }
  JeebisRotationAnimator { id: renderMotion; target: rotor; from: 0; to: 360; baseDuration: 600 }
  property bool retreated: false
  property real previous: 0
  property real maximum: 0
  property real boundedMaximum: 0
  property real boundedMinimum: 0
  onValueChanged: { if (value < previous - 0.001) retreated = true; previous = value; maximum = Math.max(maximum, value) }
  onBoundedValueChanged: { boundedMaximum = Math.max(boundedMaximum, boundedValue); boundedMinimum = Math.min(boundedMinimum, boundedValue) }
  JeebisNumberAnimation { id: motion; target: testCase; property: "value"; from: 0; to: 1; baseDuration: 600 }
  JeebisNumberAnimation { id: safe; bounded: true; target: testCase; property: "boundedValue"; from: 0; to: 1; baseDuration: 600 }
  function test_motion() {
    compare(motion.preset, "${preset}")
    compare(motion.easing.type, ${preset === 'Linear' ? 'Easing.Linear' : preset === 'InOutSine' ? 'Easing.InOutSine' : preset === 'OutBounce' ? 'Easing.OutBounce' : preset === 'InQuart' ? 'Easing.InQuart' : 'Easing.OutBack'})
    compare(motion.duration, 300); compare(safe.duration, 300)
    compare(colorMotion.preset, "${['Linear', 'OutBounce', 'InQuart'].includes(preset) ? preset : 'InOutSine'}")
    compare(rotationMotion.preset, "${preset}"); compare(renderMotion.preset, "${preset}")
    compare(colorMotion.duration, 300); compare(rotationMotion.duration, 300); compare(renderMotion.duration, 300)
    colorMotion.start(); rotationMotion.start()
    motion.start(); safe.start()
    tryCompare(motion, "running", false, 3000); tryCompare(safe, "running", false, 3000)
    compare(value, 1); compare(boundedValue, 1)
    tryCompare(colorMotion, "running", false, 3000); tryCompare(rotationMotion, "running", false, 3000)
    compare(tint.toString(), "#ffffff"); compare(angle, 360)
    verify(boundedMinimum >= 0 && boundedMaximum <= 1)
    verify(${preset === 'OutBack' ? 'maximum > 1.05' : 'maximum <= 1'})
    if (motion.preset === "OutBounce") verify(retreated, "OutBounce must reverse direction during arrival")
    motion.from = 1; motion.to = 0; motion.start()
    tryCompare(motion, "running", false, 3000); compare(value, 0)
  }
}`);
    const result = cp.spawnSync(runner, ['-input', dir], {encoding:'utf8', env:{...process.env, QT_QPA_PLATFORM:'offscreen', QT_QUICK_BACKEND:'software'}});
    assert.equal(result.status, 0, result.stdout + result.stderr);
  }
} finally { fs.rmSync(dir, {recursive:true, force:true}); }
console.log('Presets: validation, Qt runtime curves, overshoot, bounded values and endpoints passed.');
