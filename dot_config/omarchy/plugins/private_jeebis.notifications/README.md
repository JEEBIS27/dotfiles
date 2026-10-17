# Notification island

- The bell is visible when retained unread notifications exist.
- Hovering the bell or opening its panel reveals white × (mark all read) and history buttons to its left.
- Clicking the bell toggles an unread-only panel. Entries do not expire while being read.
- The history button opens retained read and unread notifications in a stable history view.
- Opening or closing either view does not mark notifications as read.
- Clicking × marks the current snapshot as read and closes the panel. Later arrivals remain unread.
- Escape / outside click closes the panel. X marks all read; J/K or arrows scroll.
- Read state is stored under `$XDG_STATE_HOME/omarchy/notification-island/read.json`.
- Notification files remain managed by Omarchy. The bell view excludes read entries; the history view includes them. Neither view replays expiring toasts.

IPC: `omarchy-shell jeebis.notifications open`, `openHistory`, `close`, `toggle`, `markAllRead`, `refresh`, `state`.
