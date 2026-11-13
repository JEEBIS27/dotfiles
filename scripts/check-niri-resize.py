"""Regression tests for recency, visible pairs and full-width round trips."""
import copy
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'packages/desktop'))
import niri_resize as resize
spec = importlib.util.spec_from_file_location('auto', ROOT / 'packages/desktop/niri-auto-width.py')
auto = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auto)


def window(identifier, column, value=50, workspace=1, floating=False):
    width = (1920 - resize.GAP) * value / 100 - resize.GAP
    return dict(id=identifier, workspace_id=workspace, is_floating=floating,
                layout=dict(pos_in_scrolling_layout=[column, 1], tile_size=[width, 1000],
                            window_size=[round(width), 1000]))


class Desktop:
    def __init__(self):
        self.windows = [window(i, i) for i in (1, 2, 3)]
        self.focused = 2
        self.actions = []
        self.frames = []

    def request(self, message):
        if message == 'Windows':
            return {'Windows': copy.deepcopy(self.windows)}
        if message == 'FocusedWindow':
            return {'FocusedWindow': copy.deepcopy(self.windows[self.focused - 1])}
        action = message['Action']
        self.actions.append(action)
        if 'SetWindowWidth' in action:
            args = action['SetWindowWidth']
            w = self.windows[args['id'] - 1]
            if 'SetFixed' in args['change']:
                w['layout']['tile_size'][0] = args['change']['SetFixed']
            else:
                value = args['change']['SetProportion']
                w['layout']['tile_size'][0] = (1920 - resize.GAP) * value / 100 - resize.GAP
            w['layout']['window_size'][0] = round(w['layout']['tile_size'][0])
        elif 'CenterWindow' in action:
            self.frames.append((self.focused, action['CenterWindow']['id']))
        else:
            raise AssertionError(action)
        return 'Handled'

    def values(self):
        return [round(resize.percentage(w, 1920), 2) for w in self.windows]


class ResizeTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.desktop = Desktop()
        for mock in [patch.dict(os.environ, XDG_RUNTIME_DIR=directory.name, NIRI_SOCKET='test-session'),
                     patch.object(resize, 'request', side_effect=self.desktop.request),
                     patch.object(resize, 'output_width', return_value=1920)]:
            mock.start()
            self.addCleanup(mock.stop)

    def test_conversation_middle_40_then_focus_right(self):
        state = resize.ResizeState()
        a, b, c = self.desktop.windows
        state.remember_pair(a, b)
        state.resize_to(copy.deepcopy(self.desktop.windows), copy.deepcopy(b), 40)
        self.assertEqual(self.desktop.values(), [60, 40, 50])
        self.assertEqual(state.data['history']['1'], state.data['history']['2'])
        self.assertNotIn('3', state.data['history'])
        self.desktop.focused = 3
        state.focus(copy.deepcopy(self.desktop.windows), copy.deepcopy(b), copy.deepcopy(c))
        self.assertEqual(self.desktop.values(), [60, 40, 60])
        self.assertGreater(state.data['history']['3'], state.data['history']['2'])
        self.assertEqual(self.desktop.frames[-1], (3, 2))
        self.desktop.focused = 2
        state.focus(copy.deepcopy(self.desktop.windows), copy.deepcopy(c), copy.deepcopy(b))
        self.assertEqual(self.desktop.values(), [60, 40, 60])
        self.desktop.focused = 1
        state.focus(copy.deepcopy(self.desktop.windows), copy.deepcopy(b), copy.deepcopy(a))
        self.assertEqual(self.desktop.values(), [60, 40, 60])

    def test_conversation_right_70_then_move_back_to_left(self):
        state = resize.ResizeState()
        a, b, c = self.desktop.windows
        state.remember_pair(a, b)
        state.resize_to(copy.deepcopy(self.desktop.windows), copy.deepcopy(b), 40)
        self.desktop.focused = 3
        state.focus(copy.deepcopy(self.desktop.windows), copy.deepcopy(b), copy.deepcopy(c))
        state.resize_to(copy.deepcopy(self.desktop.windows), copy.deepcopy(c), 70)
        self.assertEqual(self.desktop.values(), [60, 30, 70])
        self.desktop.focused = 2
        state.focus(copy.deepcopy(self.desktop.windows), copy.deepcopy(c), copy.deepcopy(b))
        self.desktop.focused = 1
        state.focus(copy.deepcopy(self.desktop.windows), copy.deepcopy(b), copy.deepcopy(a))
        self.assertEqual(self.desktop.values(), [70, 30, 70])

    def test_newer_automatic_resize_beats_older_manual_resize(self):
        state = resize.ResizeState()
        a, b, c = self.desktop.windows
        state.resize_to(copy.deepcopy(self.desktop.windows), copy.deepcopy(a), 60)
        self.desktop.focused = 3
        state.focus(copy.deepcopy(self.desktop.windows), copy.deepcopy(b), copy.deepcopy(c))
        self.assertGreater(state.data['history']['3'], state.data['history']['2'])
        self.desktop.focused = 2
        state.focus(copy.deepcopy(self.desktop.windows), copy.deepcopy(c), copy.deepcopy(b))
        self.assertEqual(self.desktop.values(), [60, 40, 60])

    def test_unchanged_width_does_not_refresh_history(self):
        state = resize.ResizeState()
        a, b, _ = self.desktop.windows
        state.remember_pair(a, b)
        state.resize_to(copy.deepcopy(self.desktop.windows), copy.deepcopy(b), 40)
        history = dict(state.data['history'])
        state.resize_to(copy.deepcopy(self.desktop.windows), copy.deepcopy(b), 40)
        self.assertEqual(history, state.data['history'])

    def test_equal_history_keeps_previous_focus(self):
        state = resize.ResizeState()
        self.desktop.windows[0] = window(1, 1, 60)
        a, b, _ = copy.deepcopy(self.desktop.windows)
        state.focus(copy.deepcopy(self.desktop.windows), a, b)
        self.assertEqual(self.desktop.values(), [60, 40, 50])

    def test_middle_full_width_restores_original_partner(self):
        for partner in (1, 3):
            self.desktop = Desktop()
            # Patch resolves self.desktop dynamically through its request method.
            with patch.object(resize, 'request', side_effect=self.desktop.request):
                state = resize.ResizeState()
                a, b, c = self.desktop.windows
                peer = self.desktop.windows[partner - 1]
                state.remember_pair(b, peer)
                state.resize_to(copy.deepcopy(self.desktop.windows), copy.deepcopy(b), 100)
                self.assertEqual(self.desktop.values()[1], 100)
                self.assertEqual(state.data['full']['2']['partner'], partner)
                state.resize_to(copy.deepcopy(self.desktop.windows), copy.deepcopy(b), 50)
                self.assertEqual(self.desktop.values(), [50, 50, 50])
                self.assertEqual(self.desktop.frames[-1], (2, partner))

    def test_rightmost_full_width_restores_left_pair_without_focus_changes(self):
        self.desktop.focused = 3
        state = resize.ResizeState()
        c = self.desktop.windows[2]
        state.resize_to(copy.deepcopy(self.desktop.windows), copy.deepcopy(c), 100)
        state.resize_to(copy.deepcopy(self.desktop.windows), copy.deepcopy(c), 50)
        self.assertEqual(self.desktop.values(), [50, 50, 50])
        self.assertEqual(self.desktop.frames[-1], (3, 2))
        self.assertFalse(any(any(key.startswith('Focus') for key in action) for action in self.desktop.actions))

    def test_keyboard_steps_persist_history_and_pair(self):
        with resize.state_transaction() as state:
            state.remember_pair(self.desktop.windows[0], self.desktop.windows[1])
        resize.resize(-10)
        self.assertEqual(self.desktop.values(), [60, 40, 50])
        resize.resize(10)
        self.assertEqual(self.desktop.values(), [50, 50, 50])
        resize.resize(toggle=True)
        self.assertEqual(self.desktop.values(), [50, 100, 50])
        resize.resize(toggle=True)
        self.assertEqual(self.desktop.values(), [50, 50, 50])
        self.assertEqual(self.desktop.frames[-1], (2, 1))

    def test_mouse_debounce_and_immediate_next_external_resize(self):
        observer = resize.SettledResize()
        with resize.state_transaction() as state:
            state.remember_pair(self.desktop.windows[0], self.desktop.windows[1])
        observer.observe(copy.deepcopy(self.desktop.windows), 0)
        self.desktop.windows[1] = window(2, 2, 40)
        observer.observe(copy.deepcopy(self.desktop.windows), 1)
        self.assertAlmostEqual(observer.pending[2], 1.3)
        observer.observe(copy.deepcopy(self.desktop.windows), 1.1)
        self.assertAlmostEqual(observer.pending[2], 1.3)
        observer.settle(copy.deepcopy(self.desktop.windows))
        self.assertEqual(self.desktop.values(), [60, 40, 50])
        observer.observe(copy.deepcopy(self.desktop.windows), 1.4)
        self.assertIsNone(observer.pending)
        self.desktop.windows[1] = window(2, 2, 30)
        observer.observe(copy.deepcopy(self.desktop.windows), 1.5)
        self.assertIsNotNone(observer.pending)
        observer.settle(copy.deepcopy(self.desktop.windows))
        self.assertEqual(self.desktop.values(), [70, 30, 50])

    def test_external_full_width_round_trip_captures_pair(self):
        observer = resize.SettledResize()
        with resize.state_transaction() as state:
            state.remember_pair(self.desktop.windows[0], self.desktop.windows[1])
        observer.observe(copy.deepcopy(self.desktop.windows), 0)
        self.desktop.windows[1] = window(2, 2, 100)
        observer.observe(copy.deepcopy(self.desktop.windows), 1)
        observer.settle(copy.deepcopy(self.desktop.windows))
        self.desktop.windows[1] = window(2, 2, 50)
        observer.observe(copy.deepcopy(self.desktop.windows), 2)
        observer.settle(copy.deepcopy(self.desktop.windows))
        self.assertEqual(self.desktop.frames[-1], (2, 1))

    def test_fast_full_width_round_trip_restarts_debounce(self):
        observer = resize.SettledResize()
        with resize.state_transaction() as state:
            state.remember_pair(self.desktop.windows[0], self.desktop.windows[1])
        observer.observe(copy.deepcopy(self.desktop.windows), 0)
        self.desktop.windows[1] = window(2, 2, 100)
        observer.observe(copy.deepcopy(self.desktop.windows), 1)
        self.desktop.windows[1] = window(2, 2, 50)
        observer.observe(copy.deepcopy(self.desktop.windows), 1.2)
        self.assertAlmostEqual(observer.pending[2], 1.5)
        observer.settle(copy.deepcopy(self.desktop.windows))
        self.assertEqual(self.desktop.frames[-1], (2, 1))

    def test_history_reset_on_new_compositor_session_and_pruning(self):
        with resize.state_transaction() as state:
            state.stamp([self.desktop.windows[0]])
            state.prune(self.desktop.windows[1:])
            self.assertNotIn('1', state.data['history'])
            state.stamp([self.desktop.windows[1]])
        with patch.dict(os.environ, NIRI_SOCKET='new-session'), resize.state_transaction() as state:
            self.assertEqual(state.data['history'], {})

    def test_stacked_columns_and_other_workspace_are_not_neighbors(self):
        self.desktop.windows = [window(1, 1), window(2, 1), window(3, 2), window(4, 1, workspace=2)]
        groups = resize.columns(self.desktop.windows, 1)
        self.assertEqual(len(groups), 2)
        self.assertEqual(len(groups[1]), 2)
        state = resize.ResizeState()
        self.assertEqual(state.partner(self.desktop.windows, self.desktop.windows[1])['id'], 3)

    def test_single_column_remains_full_width(self):
        self.desktop.windows = [window(1, 1, 100)]
        self.desktop.focused = 1
        resize.resize(-10)
        self.assertEqual(self.desktop.values(), [100])


if __name__ == '__main__':
    unittest.main()
