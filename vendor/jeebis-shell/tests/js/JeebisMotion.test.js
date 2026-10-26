// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const vm = require('node:vm'), assert = require('node:assert/strict'), cp = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const config = fs.readFileSync(root + '/ShellConfig.js', 'utf8');
const model = vm.createContext({});
vm.runInContext(config.replace(/^\.pragma library\s*/, ''), model);
for (const preset of ['linear', 'smooth', 'overshoot', 'invalid']) {
  model.animationPreset = preset;
  assert.equal(model.motionPreset(false), preset === 'invalid' ? 'smooth' : preset);
  assert.equal(model.motionPreset(true), preset === 'linear' ? 'linear' : 'smooth');
}
for (const [value, expected] of [[-2,0], [100,3], [NaN,1.70158], [1,1]]) {
  model.animationOvershoot = value; assert.equal(model.motionOvershoot(), expected);
}
const runner = '/usr/lib/qt6/bin/qmltestrunner';
if (!fs.existsSync(runner)) { console.log('Preset validation passed; Qt sampling skipped (qmltestrunner unavailable).'); process.exit(0); }
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'jeebis-motion-test-'));
try {
  const component = fs.readFileSync(root + '/bars/widgets/ruixen.apps/JeebisNumberAnimation.qml', 'utf8');
  fs.writeFileSync(dir + '/JeebisNumberAnimation.qml', component.replace('../../../ShellConfig.js', 'ShellConfig.js'));
  for (const preset of ['linear', 'smooth', 'overshoot']) {
    fs.writeFileSync(dir + '/ShellConfig.js', config.replace(/var animationPreset = "[^"]*";/, `var animationPreset = "${preset}";`));
    fs.writeFileSync(dir + '/tst_motion.qml', `import QtQuick
import QtTest
TestCase {
  id: testCase
  name: "Motion_${preset}"
  property real value: 0
  property real boundedValue: 0
  property real maximum: 0
  property real boundedMaximum: 0
  property real boundedMinimum: 0
  onValueChanged: maximum = Math.max(maximum, value)
  onBoundedValueChanged: { boundedMaximum = Math.max(boundedMaximum, boundedValue); boundedMinimum = Math.min(boundedMinimum, boundedValue) }
  JeebisNumberAnimation { id: motion; target: testCase; property: "value"; from: 0; to: 1; duration: 600 }
  JeebisNumberAnimation { id: safe; bounded: true; target: testCase; property: "boundedValue"; from: 0; to: 1; duration: 600 }
  function test_motion() {
    compare(motion.preset, "${preset}")
    compare(motion.easing.type, ${preset === 'linear' ? 'Easing.Linear' : preset === 'smooth' ? 'Easing.InOutSine' : 'Easing.OutBack'})
    motion.start(); safe.start()
    tryCompare(motion, "running", false, 3000); tryCompare(safe, "running", false, 3000)
    compare(value, 1); compare(boundedValue, 1)
    verify(boundedMinimum >= 0 && boundedMaximum <= 1)
    verify(${preset === 'overshoot' ? 'maximum > 1.05' : 'maximum <= 1'})
    motion.from = 1; motion.to = 0; motion.start()
    tryCompare(motion, "running", false, 3000); compare(value, 0)
  }
}`);
    const result = cp.spawnSync(runner, ['-input', dir], {encoding:'utf8', env:{...process.env, QT_QPA_PLATFORM:'offscreen', QT_QUICK_BACKEND:'software'}});
    assert.equal(result.status, 0, result.stdout + result.stderr);
  }
} finally { fs.rmSync(dir, {recursive:true, force:true}); }
console.log('Presets: validation, Qt runtime curves, overshoot, bounded values and endpoints passed.');
