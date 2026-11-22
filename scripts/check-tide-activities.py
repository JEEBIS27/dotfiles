"""Exercise two concurrent callers, action routing, cancellation and Codex registration."""
import asyncio
import importlib.util
import json
import os
import sys
import tempfile
import tomllib
from pathlib import Path


async def check(binary, directory):
    env = {**os.environ, "XDG_RUNTIME_DIR": directory, "PATH": os.defpath,
           "DBUS_SESSION_BUS_ADDRESS": f"unix:path={directory}/bus", "NIRI_SOCKET": f"{directory}/niri.sock"}
    server = await asyncio.create_subprocess_exec(binary, "serve", stdin=-1, stdout=-1, stderr=-1, env=env)
    sock = Path(directory) / "tide-island/activity.sock"

    async def state(predicate):
        async with asyncio.timeout(5):
            while True:
                raw = await server.stdout.readline()
                assert raw, "broker ended"
                msg = json.loads(raw)
                if predicate(msg):
                    return msg

    async def caller(key, **values):
        read, write = await asyncio.open_unix_connection(sock)
        write.write((json.dumps(dict(id=key, **values)) + "\n").encode())
        await write.drain()
        return read, write

    async def send(**fields):
        server.stdin.write((json.dumps(fields) + "\n").encode())
        await server.stdin.drain()

    async def cli(*args, data=None):
        p = await asyncio.create_subprocess_exec(binary, *args, env=env, stdin=-1, stdout=-1)
        out, _ = await p.communicate(data)
        assert p.returncode == 0, args
        return out

    def has(key):
        return lambda m: any(r["id"] == "job:" + key for r in m.get("items", []))

    try:
        await state(lambda m: "items" in m)
        assert sock.stat().st_mode & 0o777 == 0o600
        await cli("working", "--id", "build", "--title", "Install", "--app", "Installer")
        await cli("progress", "--id", "build", "--title", "Install", "--value", "32")
        first, first_w = await caller("one", op="ask", title="自由文", choices=["続行"])
        msg = await state(has("one"))
        row = msg["items"][0]
        assert row["id"] == "job:one" and msg["items"][1]["value"] == 32
        assert msg["items"][1]["source"]["app"] == "Installer"
        second, second_w = await caller("two", op="ask", title="二つ目", choices=["はい", "いいえ"])
        msg = await state(has("two"))
        r2 = next(r for r in msg["items"] if r["id"] == "job:two")
        for token, answer in ((r2["token"], "wrong request"), (row["token"], " \n  ")):
            await send(op="reply", id=row["id"], token=token, value=answer)
            await state(lambda m: "error" in m)
        answer = "本文です。\n二行目 $HOME と `text`"
        await send(op="reply", id=row["id"], token=row["token"], value=answer)
        assert json.loads(await first.readline()) == {"answer": answer, "type": "text"}
        first_w.close()
        await send(op="reply", id=row["id"], token=row["token"], value=answer)
        await state(lambda m: "error" in m)
        await send(op="reply", id=r2["id"], token=r2["token"], choice=True, value="はい")
        assert json.loads(await second.readline()) == {"answer": "はい", "type": "choice"}
        second_w.close()
        for op in ("reply", "skip"):
            third, third_w = await caller("optional", op="ask", title="Options", choices=["A"])
            item = next(r for r in (await state(has("optional")))["items"] if r["id"] == "job:optional")
            await send(op=op, id=item["id"], token=item["token"], option="A", value="追記")
            expected = {"type":"skipped"} if op == "skip" else {"type":"choice_and_text","option":"A","answer":"追記"}
            assert json.loads(await third.readline()) == expected
            third_w.close()
        _, abandoned = await caller("old", op="ask", title="Cancelled")
        await state(has("old"))
        abandoned.close()
        await state(lambda m: "items" in m and not has("old")(m))

        mcp = await asyncio.create_subprocess_exec(binary, "mcp", stdin=-1, stdout=-1, env=env)
        mcp.stdin.write(b'{"jsonrpc":"2.0","id":1,"method":"tools/list"}\n')
        assert json.loads(await mcp.stdout.readline())["result"]["tools"][0]["name"] == "ask_user"
        mcp.stdin.write(b'{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"ask_user","arguments":{"question":"Which branch?"}}}\n')
        q = (await state(lambda m: any(r["kind"] == "needs" for r in m.get("items", []))))["items"][0]
        await send(op="reply", id=q["id"], token=q["token"], value=answer)
        assert json.loads(await mcp.stdout.readline())["result"]["content"][0]["text"] == answer
        mcp.stdin.close()
        await mcp.wait()
        await cli("hook", "--app", "Codex", data=b'{"hook_event_name":"UserPromptSubmit","session_id":"sample"}')
        await state(has("ai:sample"))
        await cli("hook", "--app", "Codex", data=b'{"hook_event_name":"PermissionRequest","session_id":"sample","tool_name":"Bash"}')
        # Let a subsequent hook delimit the snapshots without relying on a sleep.
        await cli("hook", "--app", "Codex", data=b'{"hook_event_name":"PostToolUse","session_id":"sample","tool_name":"Bash"}')

        def still_working(message):
            for activity in message.get("items", []):
                if activity["id"] == "job:ai:sample":
                    assert activity["kind"] == "working", "PermissionRequest alone does not establish a user wait"
                    return activity["body"] == "Bash"
            return False

        await state(still_working)
        await cli("hook", "--app", "Codex", data=b'{"hook_event_name":"Stop","session_id":"sample"}')
        final = await state(lambda m: any(r["kind"] == "done" for r in m.get("items", [])))
        assert final["history"][0]["source"]["app"] == "Codex"
        print("PASS priority, progress, source identity, free text, choices with notes, skip, isolation, cancellation, MCP, Codex lifecycle")
    finally:
        server.stdin.close()
        await asyncio.wait_for(server.wait(), 5)


def check_config(directory):
    path = Path(__file__).with_name("tide-codex.py")
    spec = importlib.util.spec_from_file_location("tide_codex", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    config = directory / "config.toml"
    hooks = directory / "hooks.json"
    config.write_text('# local\n[features]\nhooks = true\n')
    original = {"hooks":[{"type":"command","command":"other"}]}
    old_permission = {"type": "command", "command": "/desktop/tide-activity hook --app Codex --desktop chatgpt", "timeout": 4}
    hooks.write_text(json.dumps({"hooks": {
        "Stop": [original],
        "PermissionRequest": [original, {"matcher": "Bash", "hooks": [old_permission, original["hooks"][0]]}],
    }}))
    for _ in range(2):
        module.configure(directory, Path("/desktop/tide-activity"))
    assert config.read_text().startswith("# local") and tomllib.loads(config.read_text())["features"]["hooks"]
    saved = json.loads(hooks.read_text())["hooks"]
    assert len(saved["Stop"]) == 2 and saved["Stop"][0] == original
    assert saved["PermissionRequest"] == [original, {"matcher": "Bash", **original}]
    print("PASS idempotent configuration merge")


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as directory:
        check_config(Path(directory))
        asyncio.run(asyncio.wait_for(check(sys.argv[1], directory), 25))
