"""Pair Niri columns using actual width-update recency and restore their view."""
import argparse
from contextlib import contextmanager
import fcntl
import json
import math
import os
from pathlib import Path
import socket
import time

GAP = 4  # Managed layout; no horizontal struts/side panels.


def request(message):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(3)
        connection.connect(os.environ['NIRI_SOCKET'])
        connection.sendall(json.dumps(message).encode() + b'\n')
        with connection.makefile('rb') as stream:
            reply = json.loads(stream.readline())
        if 'Err' in reply:
            raise RuntimeError(str(reply['Err']))
        return reply['Ok']


def columns(windows, workspace):
    result = {}
    for w in windows:
        pos = w.get('layout', {}).get('pos_in_scrolling_layout')
        if w.get('workspace_id') == workspace and not w['is_floating'] and pos:
            result.setdefault(pos[0], []).append(w)
    return dict(sorted(result.items()))


def percentage(window, width):
    return (window['layout']['tile_size'][0] + GAP) / (width - GAP) * 100


def output_width(window):
    workspace = next(w for w in request('Workspaces')['Workspaces']
                     if w['id'] == window['workspace_id'])
    output = request('Outputs')['Outputs'].get(workspace['output'])
    if not output or not output.get('logical'):
        raise RuntimeError('Workspace has no active output')
    return output['logical']['width']


def lock_path():
    return Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / f'jeebis-niri-resize-{os.getuid()}.lock'


@contextmanager
def state_transaction():
    # The socket identifies a compositor session; reused window IDs in a new
    # session must never inherit history. Share history across helper processes.
    with lock_path().open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = lock_path().with_suffix('.json')
        try:
            data = json.loads(path.read_text())
        except (FileNotFoundError, ValueError):
            data = {}
        state = ResizeState(data if data.get('socket') == os.environ.get('NIRI_SOCKET') else {})
        yield state
        temporary = path.with_suffix('.tmp')
        temporary.write_text(json.dumps(state.data))
        temporary.replace(path)


class ResizeState:
    def __init__(self, data=None):
        self.data = data if data is not None else {}
        self.data.setdefault('socket', os.environ.get('NIRI_SOCKET'))
        for key in ('history', 'pairs', 'full', 'expected'):
            self.data.setdefault(key, {})
        self.data.setdefault('sequence', 0)

    def stamp(self, windows):
        if not windows:
            return
        self.data['sequence'] += 1
        for w in windows:
            self.data['history'][str(w['id'])] = self.data['sequence']

    def age(self, windows, target):
        pos = target['layout']['pos_in_scrolling_layout'][0]
        group = columns(windows, target['workspace_id']).get(pos, [])
        return max((self.data['history'].get(str(w['id']), 0) for w in group), default=0)

    def remember_pair(self, a, b):
        self.data['pairs'][str(a['id'])] = b['id']
        self.data['pairs'][str(b['id'])] = a['id']

    def partner(self, windows, target):
        groups = columns(windows, target['workspace_id'])
        pos = target.get('layout', {}).get('pos_in_scrolling_layout')
        if not pos or len(groups) < 2:
            return None
        adjacent = [groups[k][0] for k in groups if abs(k - pos[0]) == 1]
        saved = self.data['full'].get(str(target['id']), {}).get('partner')
        cached = self.data['pairs'].get(str(target['id']))
        for identifier in (saved, cached):
            match = next((w for w in adjacent if w['id'] == identifier), None)
            if match:
                return match
        # Initial pairing: prefer a fully visible adjacent column when the
        # compositor provides view coordinates, otherwise the left neighbor.
        width = output_width(target)
        def visible(w):
            point = w['layout'].get('tile_pos_in_workspace_view')
            return bool(point and point[0] >= GAP - 2 and
                        point[0] + w['layout']['tile_size'][0] <= width - GAP + 2)
        return next((w for w in adjacent if visible(w)), adjacent[0] if adjacent else None)

    def apply(self, windows, changes, frame=None, fixed=None):
        changed = []
        for target, value in changes:
            width = output_width(target)
            if abs(percentage(target, width) - value) < 0.12:
                continue
            request({'Action': {'SetWindowWidth': {
                'id': target['id'], 'change': ({'SetFixed': fixed[1]} if fixed and fixed[0] == target['id'] else {'SetProportion': value}),
            }}})
            pos = target['layout'].get('pos_in_scrolling_layout')
            group = columns(windows, target['workspace_id']).get(pos[0], [target]) if pos else [target]
            changed.extend(group)
            for w in group:
                self.data['expected'][str(w['id'])] = [value, time.monotonic() + 2, percentage(w, width)]
        self.stamp(changed)
        if frame:
            self.data['frame'] = [frame[0]['id'], frame[1]['id']]
            self.frame_ready(request('Windows')['Windows'])

    def frame_ready(self, windows):
        identifiers = self.data.get('frame', [])
        members = [next((w for w in windows if w['id'] == i), None) for i in identifiers]
        if len(members) != 2 or any(w is None for w in members):
            self.data.pop('frame', None)
            return
        a, b = members
        if abs(percentage(a, output_width(a)) + percentage(b, output_width(b)) - 100) > 0.2:
            return
        self.frame(a, b)
        self.data.pop('frame', None)

    @staticmethod
    def frame(a, b):
        # Patched Niri frames an adjacent pair via CenterWindow on the inactive
        # member. No temporary focus changes or window-width tricks are needed.
        active = request('FocusedWindow')['FocusedWindow']
        if active and active['id'] in (a['id'], b['id']):
            inactive = b if active['id'] == a['id'] else a
            request({'Action': {'CenterWindow': {'id': inactive['id']}}})

    def resize_to(self, windows, target, value, fixed=None):
        neighbor = self.partner(windows, target)
        if neighbor is None:
            self.apply(windows, [(target, 100.0)])
            return
        if value >= 99.8:
            self.data['full'].setdefault(str(target['id']), {
                'partner': neighbor['id'], 'width': percentage(target, output_width(target)),
                'pixels': target['layout']['window_size'][0],
            })
            self.apply(windows, [(target, 100.0)])
            return
        self.remember_pair(target, neighbor)
        self.data['full'].pop(str(target['id']), None)
        value = max(10.0, min(90.0, value))
        self.apply(windows, [(target, value), (neighbor, 100.0 - value)], frame=(target, neighbor),
                   fixed=(target['id'], fixed) if fixed is not None else None)

    def focus(self, windows, previous, target):
        if previous is None or target is None or previous['is_floating'] or target['is_floating']:
            return
        if previous['workspace_id'] != target['workspace_id']:
            return
        a = previous.get('layout', {}).get('pos_in_scrolling_layout')
        b = target.get('layout', {}).get('pos_in_scrolling_layout')
        if not a or not b or abs(a[0] - b[0]) != 1:
            return
        # Full-width columns retain their saved partner until explicitly shrunk.
        if any(percentage(w, output_width(w)) >= 99.8 for w in (previous, target)):
            return
        keep, adjust = (target, previous) if self.age(windows, target) > self.age(windows, previous) else (previous, target)
        value = max(10.0, min(90.0, percentage(keep, output_width(keep))))
        self.remember_pair(previous, target)
        self.apply(windows, [(adjust, 100.0 - value)], frame=(previous, target))

    def prune(self, windows):
        alive = {str(w['id']) for w in windows}
        for name in ('history', 'pairs', 'full', 'expected'):
            self.data[name] = {k: v for k, v in self.data[name].items() if k in alive}


def resize(delta=None, toggle=False):
    with state_transaction() as state:
        target = request('FocusedWindow')['FocusedWindow']
        if not target:
            return
        windows = request('Windows')['Windows']
        current = percentage(target, output_width(target))
        if target['is_floating']:
            value = max(10, min(100, current + (delta or 0)))
            state.apply(windows, [(target, value)])
            return
        fixed = None
        if toggle:
            saved = state.data['full'].get(str(target['id']), {})
            value = saved.get('width', 50.0) if current >= 99.8 else 100.0
            fixed = saved.get('pixels') if current >= 99.8 else None
        else:
            value = (math.floor((current + 0.15) / 10) + 1) * 10 if delta > 0 else (math.ceil((current - 0.15) / 10) - 1) * 10
        state.resize_to(windows, target, value, fixed=fixed)


class SettledResize:
    def __init__(self):
        self.baseline = None
        self.pending = None
        self.previous_focus = None
        self.last_windows = []

    @staticmethod
    def snapshot(windows):
        result = {}
        for w in windows:
            pos = w.get('layout', {}).get('pos_in_scrolling_layout')
            if not w['is_floating'] and w.get('workspace_id') is not None and pos:
                result.setdefault((w['workspace_id'], pos[0]), (w['id'], w['layout']['tile_size'][0]))
        return result

    def observe(self, windows, now):
        snapshot = self.snapshot(windows)
        old = self.baseline
        with state_transaction() as state:
            state.prune(windows)
            # Expected geometry changes from our own actions do not start a
            # mouse compensation, including staggered client commits.
            own = set()
            for key, (identifier, width) in snapshot.items():
                expected = state.data['expected'].get(str(identifier))
                if expected:
                    target = next(w for w in windows if w['id'] == identifier)
                    current = percentage(target, output_width(target))
                    arrived = abs(current - expected[0]) < 0.12
                    unchanged = abs(current - expected[2]) < 0.12
                    if expected[1] >= time.monotonic() and (arrived or unchanged):
                        own.add(key)
                        if old and key in old:
                            old[key] = (identifier, width)
                    if arrived or not unchanged or expected[1] < time.monotonic():
                        state.data['expected'].pop(str(identifier), None)
            if old is None or old.keys() != snapshot.keys() or any(old[k][0] != snapshot[k][0] for k in snapshot):
                self.baseline, self.pending = snapshot, None
            else:
                changed = [k for k in snapshot if k not in own and abs(old[k][1] - snapshot[k][1]) > 1]
                if len(changed) == 1:
                    identifier, width = snapshot[changed[0]]
                    if self.pending is None or self.pending[:2] != (identifier, width):
                        # Capture the partner before expanding to full width.
                        target = next(w for w in windows if w['id'] == identifier)
                        before = dict(target, layout=dict(target['layout']))
                        before['layout']['tile_size'] = [old[changed[0]][1], target['layout']['tile_size'][1]]
                        if percentage(target, output_width(target)) >= 99.8:
                            neighbor = state.partner(self.last_windows, before)
                            if neighbor:
                                state.data['full'].setdefault(str(identifier), {'partner': neighbor['id'], 'width': percentage(before, output_width(before))})
                        self.pending = (identifier, width, now + 0.3)
                elif changed:
                    state.stamp([w for w in windows if w['id'] in {snapshot[k][0] for k in changed}])
                    self.baseline, self.pending = snapshot, None
                elif self.pending:
                    own_ids = {snapshot[k][0] for k in own}
                    latest = next((v for v in snapshot.values() if v[0] == self.pending[0]), None)
                    if self.pending[0] in own_ids:
                        self.pending = None
                    elif latest and abs(latest[1] - self.pending[1]) > 1:
                        self.pending = (latest[0], latest[1], now + 0.3)
            state.frame_ready(windows)
        self.last_windows = windows

    def focus(self, windows, identifier):
        target = next((w for w in windows if w['id'] == identifier), None)
        if not target:
            return
        previous = next((w for w in windows if w['id'] == self.previous_focus), None)
        self.previous_focus = identifier
        if previous and previous['id'] != identifier:
            with state_transaction() as state:
                state.focus(windows, previous, target)

    def settle(self, windows):
        pending, self.pending = self.pending, None
        if pending:
            target = next((w for w in windows if w['id'] == pending[0]), None)
            if target and not target['is_floating']:
                with state_transaction() as state:
                    # The externally changed target and its compensated neighbor
                    # receive one stamp for this single operation.
                    before = dict(state.data['history'])
                    state.resize_to(windows, target, percentage(target, output_width(target)))
                    stamp = state.data['sequence']
                    if before == state.data['history']:
                        state.stamp([target])
                    else:
                        state.data['history'][str(target['id'])] = stamp
        self.baseline = self.snapshot(request('Windows')['Windows'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('direction', choices=['grow', 'shrink', 'toggle-maximize'])
    args = parser.parse_args()
    resize(toggle=True) if args.direction == 'toggle-maximize' else resize(10 if args.direction == 'grow' else -10)
