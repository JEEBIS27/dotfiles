#!/usr/bin/env python3
# Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('rotation', ROOT/'bars/widgets/ruixen.notch/JeebisDisplayRotation.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

MONITOR = dict(name='eDP-1', width=1920, height=1200, refreshRate=60.026,
               x=0, y=0, scale=1.6, transform=0, vrr=False,
               colorManagementPreset='srgb', currentFormat='XRGB8888')

class RotationTests(unittest.TestCase):
    def test_only_internal_output_is_chosen(self):
        self.assertIsNone(module.select_monitor([dict(name='HDMI-A-1')]))
        self.assertEqual(module.select_monitor([dict(name='HDMI-A-1'),MONITOR]),MONITOR)
        self.assertIsNone(module.select_monitor([MONITOR],'eDP-2'))

    def test_sensor_orientation_and_stability(self):
        self.assertEqual(module.orientation([0,-9,2]),0)
        self.assertEqual(module.orientation([0,9,2]),2)
        self.assertEqual(module.orientation([0,9,2],1),0)
        for vector in ([0,0,0],[0,1,9],[9,1,0],[float('nan'),0,0]):
            self.assertIsNone(module.orientation(vector))
        stable=module.StableOrientation(1.5)
        self.assertIsNone(stable.update(2,0))
        self.assertIsNone(stable.update(2,1))
        self.assertEqual(stable.update(2,1.5),2)
        self.assertIsNone(stable.update(2,1.8))
        self.assertIsNone(stable.update(None,1.9))
        self.assertIsNone(stable.update(2,2.0))
        self.assertIsNone(stable.update(2,3.6))
        self.assertIsNone(stable.update(None,2))
        self.assertIsNone(stable.update(2,2.1))
        self.assertIsNone(stable.update(0,3.0))
        self.assertEqual(stable.update(0,4.5),0)

    def test_mount_matrix_and_corrupt_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for axis,value in zip('xyz',[1,-9,2]):(root/f'in_accel_{axis}_raw').write_text(str(value))
            (root/'in_accel_mount_matrix').write_text('1,0,0;0,-1,0;0,0,1')
            self.assertEqual(module.read_vector(root),[1,9,2])
            self.assertEqual(module.sensor_path({'sensor':str(root)}),root)
            path=root/'state.json';path.write_text('broken')
            self.assertEqual(module.load_state(path,{'automatic':True})['automatic'],True)
            module.save_state(path,{'automatic':False,'transform':2})
            self.assertEqual(json.loads(path.read_text())['transform'],2)
            self.assertEqual(len(list(root.glob('.rotation-*'))),0)

    def test_reload_rule_keeps_inverted_orientation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/"display-rotation.lua"
            module.save_rotation_rule(path, MONITOR, 2, {"touchDevices": ["internal-touch"]})
            self.assertEqual(path.read_text().strip(), module.rotation_command(MONITOR, 2, ["internal-touch"]))
            self.assertEqual(list(path.parent.glob(".rotation-*")), [])

    def test_preserve_mode_and_target_touch_only(self):
        command=module.rotation_command(MONITOR,2,['internal-touch'])
        self.assertIn('scale = 1.6',command)
        self.assertIn('mode = "1920x1200@60.02600"',command)
        self.assertIn('position = "0x0"',command)
        self.assertIn('name = "internal-touch"',command)
        self.assertNotIn('touchdevice',command) # no global input override
        portrait=dict(MONITOR,width=1200,height=1920,transform=1)
        self.assertIn('1920x1200@',module.rotation_command(portrait,3,[]))
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'check.lua'
            path.write_text('hl={monitor=function(x) assert(x.scale==1.6);assert(x.transform==2) end, device=function(x) assert(x.name=="internal-touch");assert(x.output=="eDP-1") end}\n'+command)
            subprocess.run(['lua',str(path)],check=True)

    def test_apply_verifies_compositor_and_reports_failure(self):
        with patch.object(module,'run',return_value='ok'),patch.object(module,'monitors',return_value=[dict(MONITOR,transform=2)]):
            module.apply(MONITOR,2,{})
        with patch.object(module,'run',return_value='error: no output'):
            with self.assertRaises(RuntimeError):module.apply(MONITOR,2,{})
        with patch.object(module,'run',return_value='ok'),patch.object(module,'monitors',return_value=[MONITOR]),patch.object(module.time,'monotonic',side_effect=[0,3]):
            with self.assertRaises(RuntimeError):module.apply(MONITOR,2,{})

    def test_output_commit_may_be_delayed(self):
        with patch.object(module,'run',return_value='ok'),patch.object(module,'monitors',side_effect=[[MONITOR],[dict(MONITOR,transform=2)]]),patch.object(module.time,'sleep') as sleep:
            module.apply(MONITOR,2,{})
            sleep.assert_called_once_with(.04)

    def test_transition_capture_failure_never_blocks_rotation(self):
        with patch.object(module.uuid,'uuid4') as unique, patch.object(module,'transition_ipc') as ipc:
            unique.return_value.hex='request'
            ipc.side_effect=['',json.dumps({'token':'request','phase':'idle'}) , '']
            self.assertIsNone(module.prepare_transition(MONITOR,2,{'animation':True}))
            self.assertEqual(ipc.call_args.args,('abortRotation','request'))

    def test_transition_waits_for_final_frame_and_cleans_both_outcomes(self):
        with patch.object(module.uuid,'uuid4') as unique, patch.object(module,'transition_ipc') as ipc:
            unique.return_value.hex='request'
            ipc.side_effect=['',json.dumps({'token':'request','phase':'ready'})]
            self.assertEqual(module.prepare_transition(MONITOR,2,{'animation':True}),'request')
        for success in (True,False):
            with self.subTest(success=success),patch.object(module,'prepare_transition',return_value='request'),patch.object(module,'transition_ipc',return_value='true' if success else 'false') as ipc,patch.object(module,'monitors',return_value=[dict(MONITOR,transform=2)]):
                if success:
                    module.apply(MONITOR,2,{})
                    self.assertEqual(ipc.call_args.args[0],'applyRotation')
                    self.assertEqual(ipc.call_args.args[1],'request')
                else:
                    with self.assertRaises(RuntimeError):module.apply(MONITOR,2,{})
                    self.assertEqual(ipc.call_args.args,('abortRotation','request'))

if __name__=='__main__':unittest.main()
