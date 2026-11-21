"""Tide activity broker, producer CLI and stdio MCP adapter."""
import argparse
import asyncio
import contextlib
import fcntl
import json
import os
import shutil
import socket
import struct
import sys
import time
import uuid
from pathlib import Path

from tide_origin import ancestors, capture, choose, locate, open_source, outputs, run


LIMIT = 256 * 1024
TRANSIENT = 6
RANK = {"needs": 0, "notification": 1, "done": 1, "progress": 2, "working": 3}
SOCKET = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "tide-island" / "activity.sock"


def line(obj):
    return (json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n").encode()


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def now():
    return int(time.time() * 1000)


def clean_source(data, pid):
    return {"app": str(data.get("app") or "Tide")[:200], "desktop": str(data.get("desktop") or "")[:244],
            "pid": pid, "window": str(data.get("window") or "")[:100]}


class Broker:
    def __init__(self):
        self.live = {}
        self.history = {}
        self.waiters = {}
        self.tasks = set()
        self.pending_calls = {}
        self.timers = {}

    def spawn(self, coroutine):
        task = asyncio.create_task(coroutine)
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)
        def report(t):
            if not t.cancelled() and t.exception():
                log(str(t.exception()))
        task.add_done_callback(report)
        return task

    def emit(self, **data):
        sys.stdout.buffer.write(line(data))
        sys.stdout.flush()

    def snapshot(self):
        ordered = sorted(self.live.values(), key=lambda r: (RANK[r["kind"]], -r["updated"]))
        self.emit(items=ordered, history=list(reversed(self.history.values())))

    def remove(self, key):
        self.live.pop(key, None)
        timer = self.timers.pop(key, None)
        if timer:
            timer.cancel()

    def expire(self, key):
        self.remove(key)
        self.snapshot()

    async def pin(self, source):
        with contextlib.suppress(OSError, ValueError, TimeoutError):
            w = await locate(source)
            if w:
                source.update(window=w[0], windowApp=w[1])

    def put(self, key, kind, title, body, source, *, choices=(), token="", value=None, native=0, actions=(), started=None):
        previous = self.live.get(key) or self.history.get(key)
        self.remove(key)
        if previous and not source.get("window") and previous["source"].get("window"):
            source.update({k: previous["source"][k] for k in ("window", "windowApp") if k in previous["source"]})
        if not source.get("window"):
            self.spawn(self.pin(source))
        continuing = previous and previous["kind"] not in ("done", "notification")
        row = dict(id=key, kind=kind, title=str(title or source["app"])[:512], body=str(body or "")[:8192],
                   source=source, choices=list(choices), token=token, value=value, actions=list(actions), native=native,
                   started=started or (previous["started"] if continuing else now()), updated=now())
        self.live[key] = row
        if kind in ("done", "notification") or native:
            self.history.pop(key, None)
            self.history[key] = row
            while len(self.history) > 80:
                self.history.pop(next(iter(self.history)))
        if kind in ("done", "notification"):
            self.timers[key] = asyncio.get_running_loop().call_later(TRANSIENT, self.expire, key)
        self.snapshot()
        return row

    async def producer(self, reader, writer):
        key = token = None
        try:
            message = json.loads(await asyncio.wait_for(reader.readline(), 8))
            op = message["op"]
            peer = writer.get_extra_info("socket")
            pid, uid, _ = struct.unpack("3i", peer.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
            if uid != os.getuid():
                raise ValueError("Different desktop user")
            key = "job:" + str(message.get("id") or uuid.uuid4())[:256]
            previous = self.live.get(key) or self.history.get(key) or {}
            origin = previous.get("source", {})
            source = clean_source({field: message.get(field) or origin.get(field) for field in ("app", "desktop", "window")}, pid)
            source["lineage"] = ancestors(pid)
            if op == "ask":
                if key in self.waiters:
                    raise ValueError("This question is already pending")
                token = uuid.uuid4().hex
                options = message.get("choices", [])
                if not isinstance(options, list) or len(options) > 32 or any(not isinstance(x, str) for x in options):
                    raise ValueError("Invalid choices")
                self.waiters[key] = token, writer
                self.put(key, "needs", message["title"], message.get("body"), source, token=token, choices=options)
                await reader.read(1)  # The requesting process owns the lifetime of the question.
                return
            if key in self.waiters:
                raise ValueError("This activity is awaiting its caller's reply")
            if op == "remove":
                self.remove(key)
                self.snapshot()
            elif op in ("working", "progress", "done", "attention"):
                value = message.get("value")
                if value is not None and not 0 <= float(value) <= 100:
                    raise ValueError("Progress must be between 0 and 100")
                self.put(key, "needs" if op == "attention" else op, message["title"], message.get("body"), source,
                         value=value, started=now() if message.get("newTurn") else None)
            else:
                raise ValueError("Unknown activity operation")
            writer.write(line({"ok": True}))
            await writer.drain()
        except (OSError, KeyError, TypeError, ValueError, TimeoutError) as exc:
            if not writer.is_closing():
                writer.write(line({"error": str(exc)}))
                with contextlib.suppress(OSError):
                    await writer.drain()
        finally:
            if token and self.waiters.get(key, (None,))[0] == token:
                self.waiters.pop(key)
                self.expire(key)
            writer.close()

    async def control(self, msg):
        op, key = msg.get("op"), msg.get("id")
        row = self.live.get(key) or self.history.get(key)
        if op == "local":
            self.put("local:" + uuid.uuid4().hex, "notification", msg["title"], msg.get("body"), clean_source(msg, 0))
        elif op == "clear":
            self.history.clear()
            self.snapshot()
        elif op == "outputs":
            self.emit(outputKind=msg["kind"], outputs=await outputs(msg["kind"]))
        elif op == "choose":
            await choose(msg["kind"], msg["value"])
            self.emit(outputKind=msg["kind"], outputs=await outputs(msg["kind"]))
        elif op == "capture":
            await asyncio.sleep(0.4)
            await capture(msg["value"])
        elif op == "media":
            await open_source(clean_source(msg, 0))
        elif op in ("reply", "skip"):
            waiter = self.waiters.get(key)
            if not waiter or waiter[0] != msg.get("token") or not row:
                raise ValueError("This request has ended.")
            response = {"type": "skipped"}
            if op == "reply":
                value = msg["value"]
                if not isinstance(value, str) or not value.strip() or len(value.encode()) > LIMIT // 2:
                    raise ValueError("Enter a reply within 128 KiB.")
                choice = msg.get("choice") is True
                option = value if choice else msg.get("option")
                if option and option not in row["choices"]:
                    raise ValueError("This choice has expired.")
                response = {"answer": value, "type": "choice" if choice else "text"}
                if option and not choice:
                    response.update(type="choice_and_text", option=option)
            _, writer = self.waiters.pop(key)
            self.expire(key)
            try:
                writer.write(line(response))
                await writer.drain()
            finally:
                writer.close()
        elif op in ("open", "action") and row:
            actions = dict(row["actions"])
            action = msg.get("value") if op == "action" else "default"
            if action in actions and row["native"]:
                try:
                    await run("makoctl", "invoke", "-n", row["native"], action)
                    return
                except ValueError:
                    if op == "action":
                        raise
            if op == "open":
                await open_source(row["source"])
        else:
            raise ValueError("This activity is no longer available.")

    async def controls(self):
        reader = asyncio.StreamReader(limit=LIMIT)
        await asyncio.get_running_loop().connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
        async def dispatch(raw):
            try:
                await self.control(json.loads(raw))
            except (ValueError, OSError, KeyError, TypeError, TimeoutError) as exc:
                self.emit(error=str(exc)[:300])
        async for raw in reader:
            self.spawn(dispatch(raw))

    async def notify(self, ident, data, sender):
        app, _, _, title, body, buttons, hints, _ = data
        hints = {k: v.get("data") for k, v in hints.items()}
        key = f"notify:{ident}"
        source = clean_source({"app": app, "desktop": hints.get("desktop-entry")}, 0)
        value = hints.get("value", hints.get("progress"))
        value = value if isinstance(value, (float, int)) and 0 <= value <= 100 else None
        kind = "notification" if value is None else "done" if value == 100 else "progress"
        actions = list(zip(buttons[::2], buttons[1::2]))
        self.put(key, kind, title, body, source, actions=actions, value=value, native=ident)
        with contextlib.suppress(ValueError, OSError):
            payload = await run("busctl", "--user", "--json=short", "call", "org.freedesktop.DBus",
                                "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", sender)
            source["pid"] = json.loads(payload)["data"][0]
            await self.pin(source)

    async def herdr(self):
        if not shutil.which("hc"):
            return
        seen = {}
        while True:
            try:
                listing = json.loads(await run("hc", "ls", "--json"))["terminals"]
                addresses = {w["address"] for w in listing} | set(seen)
                for address in addresses:
                    key = "herdr:" + address
                    info = json.loads(await run("hc", "get", address, "--json", check=False) or "{}")
                    status = info.get("status") or {}
                    state = status.get("state")
                    if not state and info.get("state") == "finished" and address in seen:
                        state = "done" if not info.get("exit_code") else "error"
                    stamp = (state, info.get("status_ms"), info.get("turn"))
                    if state not in ("working", "blocked", "done", "error"):
                        seen.pop(address, None)
                        if key in self.live:
                            self.expire(key)
                        continue
                    if seen.get(address) == stamp:
                        continue
                    if state in ("done", "error") and (address not in seen and now() - (info.get("status_ms") or 0) > 10000):
                        continue
                    seen[address] = stamp
                    app = status.get("app") or "Herdr"
                    source = clean_source(dict(app=app, desktop="jeebis-agents"), 0)
                    source["terminal"] = address
                    value = status.get("progress")
                    kind = {"working": "progress" if value is not None else "working", "blocked": "needs",
                            "done": "done", "error": "done"}[state]
                    label = status.get("title") or {"working":"Working", "blocked":"Needs you", "done":"Completed", "error":"Failed"}[state]
                    old = self.live.get(key)
                    self.put(key, kind, label, status.get("msg"), source, value=value,
                             started=(old or {}).get("started") or info.get("status_ms"))
                    if info.get("state") == "finished":
                        seen.pop(address, None)
            except (OSError, ValueError, KeyError, TimeoutError) as exc:
                log(f"Herdr: {exc}")
            await asyncio.sleep(4)

    def launcher_progress(self, sender, data):
        if len(data) != 2 or not data[0].startswith("application://"):
            return
        desktop = data[0].removeprefix("application://").removesuffix(".desktop")
        key = "launcher:" + sender + ":" + desktop
        attrs = {k:v["data"] for k,v in data[1].items()}
        if attrs.get("progress-visible") is False:
            old = self.live.get(key)
            if old and old.get("value") == 100:
                self.put(key, "done", "Completed", "", old["source"])
            elif old:
                self.expire(key)
        elif "progress" in attrs and (attrs.get("progress-visible") or key in self.live):
            value = max(0, min(100, round(attrs["progress"] * 100)))
            self.put(key, "progress", desktop, "Transfer in progress", clean_source(dict(app=desktop, desktop=desktop), 0), value=value)

    async def monitor(self):
        iface = "org.freedesktop.Notifications"
        while True:
            proc = await asyncio.create_subprocess_exec("busctl", "--user", "--json=short",
                f"--match=type='method_call',interface='{iface}',member='Notify'",
                f"--match=type='method_return',sender='{iface}'", f"--match=type='signal',interface='{iface}'",
                "--match=type='signal',interface='com.canonical.Unity.LauncherEntry',member='Update'",
                "monitor", stdout=-1, stderr=asyncio.subprocess.DEVNULL, limit=LIMIT)
            try:
                async for raw in proc.stdout:
                    e = json.loads(raw)
                    member = e.get("member")
                    data = e.get("payload", {}).get("data", [])
                    if member == "Update" and e.get("interface") == "com.canonical.Unity.LauncherEntry":
                        self.launcher_progress(e["sender"], data)
                    elif member == "Notify" and len(data) == 8:
                        self.pending_calls[e["sender"], e["cookie"]] = data
                        if len(self.pending_calls) > 256:
                            self.pending_calls.pop(next(iter(self.pending_calls)))
                    elif e["type"] == "method_return":
                        sender = e.get("destination")
                        sent = self.pending_calls.pop((sender, e.get("reply_cookie")), None)
                        if sent and data:
                            self.spawn(self.notify(int(data[0]), sent, sender))
                    elif member == "NotificationClosed" and data:
                        key = f"notify:{data[0]}"
                        row = self.history.get(key)
                        if row:
                            row["actions"] = []
                            if row["kind"] == "progress" or data[1] != 1:
                                self.remove(key)
                            self.snapshot()
            except (ValueError, KeyError, OSError) as exc:
                log(exc)
            finally:
                if proc.returncode is None:
                    with contextlib.suppress(ProcessLookupError):
                        proc.terminate()
                await proc.wait()
            self.pending_calls.clear()
            await asyncio.sleep(2)

    async def serve(self):
        SOCKET.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        with (SOCKET.parent / "activity.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            SOCKET.unlink(missing_ok=True)
            server = await asyncio.start_unix_server(self.producer, SOCKET, limit=LIMIT)
            SOCKET.chmod(0o600)
            async with server:
                self.spawn(self.monitor())
                self.spawn(self.herdr())
                self.snapshot()
                await self.controls()


async def request(msg):
    reader, writer = await asyncio.open_unix_connection(SOCKET, limit=LIMIT)
    try:
        writer.write(line(msg))
        await writer.drain()
        raw = await reader.readline()
        if not raw:
            raise ValueError("Tide closed before answering")
        result = json.loads(raw)
        if "error" in result:
            raise ValueError(result["error"])
        return result
    finally:
        writer.close()
        await writer.wait_closed()


def mcp_result(payload):
    return {"content": [{"type": "text", "text": payload}]}


def answer_text(result):
    if result["type"] in ("skipped", "choice_and_text"):
        return json.dumps(result, ensure_ascii=False)
    return result["answer"]


async def mcp():
    reader = asyncio.StreamReader(limit=LIMIT)
    await asyncio.get_running_loop().connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
    tasks = {}
    async def handle(msg):
        ident, method, params = msg["id"], msg["method"], msg.get("params", {})
        envelope = {"jsonrpc": "2.0", "id": ident}
        try:
            if method == "initialize":
                result = {"protocolVersion": params.get("protocolVersion", "2024-11-05"),
                          "capabilities": {"tools": {}}, "serverInfo": {"name": "tide-island", "version": "1"}}
            elif method == "ping":
                result = {}
            elif method == "tools/list":
                result = {"tools": [{"name": "ask_user", "description": "Ask the desktop user a question in Tide Island. Wait for their selected choice or free-text reply.",
                          "inputSchema": {"type": "object", "required": ["question"], "properties": {
                              "question": {"type": "string"}, "choices": {"type": "array", "items": {"type": "string"}}}}}]}
            elif method == "tools/call" and params.get("name") == "ask_user":
                args = params["arguments"]
                result = mcp_result(answer_text(await request(dict(op="ask", app=os.environ.get("TIDE_SOURCE_APP", "AI"),
                        desktop=os.environ.get("TIDE_SOURCE_DESKTOP", ""), title="Needs you", body=args["question"], choices=args.get("choices", [])))))
            else:
                envelope["error"] = {"code": -32601, "message": "Unknown method"}
            if "error" not in envelope:
                envelope["result"] = result
        except (OSError, ValueError, KeyError) as exc:
            envelope["result"] = {**mcp_result(str(exc)), "isError": True}
        sys.stdout.buffer.write(line(envelope))
        sys.stdout.flush()
    async for raw in reader:
        msg = json.loads(raw)
        if msg.get("method") == "notifications/cancelled":
            t = tasks.get(msg["params"]["requestId"])
            if t:
                t.cancel()
        elif "id" in msg:
            t = asyncio.create_task(handle(msg))
            tasks[msg["id"]] = t
            t.add_done_callback(lambda _, i=msg["id"]: tasks.pop(i, None))
    for t in tasks.values():
        t.cancel()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("op", choices=["serve", "mcp", "hook", "ask", "working", "progress", "done", "remove", "attention"])
    parser.add_argument("--id")
    parser.add_argument("--title", default="Needs you")
    parser.add_argument("--body", default="")
    parser.add_argument("--app", default=os.environ.get("TIDE_SOURCE_APP"))
    parser.add_argument("--desktop", default=os.environ.get("TIDE_SOURCE_DESKTOP", ""))
    parser.add_argument("--window")
    parser.add_argument("--choice", action="append", dest="choices", default=[])
    parser.add_argument("--value", type=float)
    args = vars(parser.parse_args())
    op = args["op"]
    if op == "serve":
        asyncio.run(Broker().serve())
    elif op == "mcp":
        asyncio.run(mcp())
    elif op == "hook":
        event = json.load(sys.stdin)
        name = event.get("hook_event_name")
        kinds = {"UserPromptSubmit": ("working", "Working"), "PreToolUse": ("working", "Working"),
                 "PostToolUse": ("working", "Working"), "PermissionRequest": ("attention", "Approval requested"),
                 "Stop": ("done", "Completed"), "Interrupt": ("remove", ""), "SessionEnd": ("remove", "")}
        if name in kinds and event.get("session_id"):
            kind, label = kinds[name]
            with contextlib.suppress(OSError, ValueError):
                asyncio.run(request(dict(op=kind, id="ai:" + event["session_id"], app=args["app"], desktop=args["desktop"],
                                         title=label, body=str(event.get("tool_name") or args["app"]),
                                         newTurn=name == "UserPromptSubmit")))
    else:
        result = asyncio.run(request(args))
        if op == "ask":
            print(answer_text(result))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as exc:
        sys.exit(str(exc))
