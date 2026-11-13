"""Expand a workspace's sole tiled window, restoring its width on a split."""
import json
import os
import queue
import socket
import threading
import time
from niri_resize import request, SettledResize, state_transaction, output_width, GAP


class AutoWidth:
    def __init__(self, send=request):
        self.send = send
        self.saved = {}
        self.membership = None

    def update(self, windows):
        tiled = {w['id']: w for w in windows
                 if not w['is_floating'] and w.get('workspace_id') is not None}
        membership = {(i, w['workspace_id']) for i, w in tiled.items()}
        if membership == self.membership:
            return
        self.membership = membership
        counts = {}
        for w in tiled.values():
            counts[w['workspace_id']] = counts.get(w['workspace_id'], 0) + 1
        for identifier in list(self.saved):
            w = tiled.get(identifier)
            if w is None:
                del self.saved[identifier]
            elif counts[w['workspace_id']] > 1:
                self.resize(identifier, {'SetFixed': round(self.saved.pop(identifier))})
        for identifier, w in tiled.items():
            if counts[w['workspace_id']] == 1 and identifier not in self.saved:
                size = w.get('layout', {}).get('tile_size')
                if size:
                    self.saved[identifier] = size[0]
                    self.resize(identifier, {'SetProportion': 100.0})

    def resize(self, identifier, change):
        if self.send is request:
            windows = request('Windows')['Windows']
            target = next((w for w in windows if w['id'] == identifier), None)
            if target:
                value = change.get('SetProportion')
                if value is None:
                    value = (change['SetFixed'] + GAP) / (output_width(target) - GAP) * 100
                with state_transaction() as state:
                    state.apply(windows, [(target, value)])
            return
        self.send({'Action': {'SetWindowWidth': {'id': identifier, 'change': change}}})


def events(messages):
    try:
        with socket.socket(socket.AF_UNIX) as connection:
            connection.connect(os.environ['NIRI_SOCKET'])
            connection.sendall(b'"EventStream"\n')
            with connection.makefile('rb') as stream:
                reply = json.loads(stream.readline())
                if 'Err' in reply:
                    raise RuntimeError(reply['Err'])
                for line in stream:
                    messages.put(json.loads(line))
        raise RuntimeError('Niri event stream closed')
    except Exception as error:
        messages.put(error)


def main():
    controller = AutoWidth()
    observer = SettledResize()
    messages = queue.Queue()
    threading.Thread(target=events, args=(messages,), daemon=True).start()
    while True:
        timeout = max(0, observer.pending[2] - time.monotonic()) if observer.pending else None
        try:
            event = messages.get(timeout=timeout)
        except queue.Empty:
            event = {}
        if isinstance(event, Exception):
            raise event
        if 'WindowFocusChanged' in event:
            windows = request('Windows')['Windows']
            identifier = event['WindowFocusChanged']['id']
            active = request('FocusedWindow')['FocusedWindow']
            if active and active['id'] == identifier:
                if observer.pending:
                    observer.settle(windows)
                    windows = request('Windows')['Windows']
                observer.focus(windows, identifier)
        if any(name in event for name in (
            'WindowsChanged', 'WindowOpenedOrChanged', 'WindowClosed',
            'WindowLayoutsChanged', 'WorkspacesChanged',
        )):
            windows = request('Windows')['Windows']
            before = controller.membership
            controller.update(windows)
            if before != controller.membership:
                # Membership changes can restore or maximize widths; do not
                # interpret those changes as a mouse resize.
                observer.baseline = None
                windows = request('Windows')['Windows']
            observer.observe(windows, time.monotonic())
            if observer.previous_focus is None:
                active = next((w for w in windows if w.get('is_focused')), None)
                if active:
                    observer.previous_focus = active['id']
        if observer.pending and time.monotonic() >= observer.pending[2]:
            observer.settle(request('Windows')['Windows'])


if __name__ == '__main__':
    main()
