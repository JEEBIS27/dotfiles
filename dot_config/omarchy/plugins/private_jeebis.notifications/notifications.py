#!/usr/bin/python3
"""Read Omarchy's retained notifications and persist a separate read watermark."""
import argparse
import json
from html.parser import HTMLParser
import math
import os
from pathlib import Path
import tempfile


def timestamp(value):
    try:
        number = float(value)
        return int(number) if math.isfinite(number) and number > 0 else 0
    except (TypeError, ValueError, OverflowError):
        return 0


def read_json(path):
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


class PlainText(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() in ('br', 'p', 'div', 'li'):
            self.parts.append('\n')

    def handle_endtag(self, tag):
        if tag.lower() in ('p', 'div', 'li'):
            self.parts.append('\n')

    def handle_data(self, data):
        self.parts.append(data)


def plain_text(value):
    parser = PlainText()
    parser.feed(str(value or '')[:20000])
    return ''.join(parser.parts).strip()


def snapshot(notifications_dir, receipt):
    last_read = timestamp(read_json(receipt).get('lastReadTimestamp'))
    entries = {}
    for directory in (notifications_dir, notifications_dir / 'history'):
        for path in directory.glob('*.json'):
            entry = read_json(path)
            # Omarchy's own action confirmations are feedback, not inbox items.
            if entry.get('app') == 'omarchy-action':
                continue
            received = timestamp(entry.get('timestamp'))
            if received:
                entries[path.name] = {
                    'key': path.name,
                    'timestamp': received,
                    'unread': received > last_read,
                    'app': str(entry.get('app') or 'Notification')[:200],
                    'summary': str(entry.get('summary') or '')[:1000],
                    'body': plain_text(entry.get('body')),
                }
    history = sorted(entries.values(), key=lambda entry: (entry['timestamp'], entry['key']), reverse=True)
    unread = [entry for entry in history if entry['unread']]
    return {
        'unreadCount': len(unread),
        'unreadItems': unread,
        'historyItems': history,
        'latestTimestamp': max((entry['timestamp'] for entry in entries.values()), default=0),
        'lastReadTimestamp': last_read,
    }


def main():
    parser = argparse.ArgumentParser()
    state_home = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state')
    # The Omarchy notification service currently uses this path explicitly.
    parser.add_argument('--notifications-dir', type=Path, default=Path.home() / '.local/state/omarchy/notifications')
    parser.add_argument('--state-dir', type=Path, default=state_home / 'omarchy/notification-island')
    parser.add_argument('--mark-read', type=int)
    args = parser.parse_args()
    args.state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    receipt = args.state_dir / 'read.json'
    if args.mark_read is not None:
        cutoff = max(timestamp(args.mark_read), timestamp(read_json(receipt).get('lastReadTimestamp')))
        fd, temporary = tempfile.mkstemp(prefix='.read-', dir=args.state_dir)
        try:
            with os.fdopen(fd, 'w') as stream:
                json.dump({'lastReadTimestamp': cutoff}, stream)
                stream.write('\n')
            os.replace(temporary, receipt)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    print(json.dumps(snapshot(args.notifications_dir, receipt)))


if __name__ == '__main__':
    main()
