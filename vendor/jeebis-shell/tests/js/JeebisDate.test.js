// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
"use strict";
const fs = require("fs"), path = require("path"), vm = require("vm");
const { check, summary } = require("./harness");
const base = path.join(__dirname, "../../bars/widgets/ruixen.date");
const modelSource = fs.readFileSync(path.join(base, "JeebisCalendarModel.js"), "utf8");
check("calendar dates are isolated from the sibling Date.qml type", modelSource.startsWith(".pragma library"), true);
const model = {};
vm.createContext(model);
vm.runInContext(modelSource.replace(/^\.pragma library\s*/, ""), model);
check("December advances to the following January", model.monthAt(2026, 11, 1), { year: 2027, month: 0 });
check("January steps back to the previous December", model.monthAt(2026, 0, -1), { year: 2025, month: 11 });
for (const [year, month, length] of [[2024, 1, 29], [2026, 1, 28], [2026, 2, 31], [2026, 8, 30]]) {
  const grid = model.monthGrid(year, month, new Date(year, month, 15, 12));
  check(`${year}/${month + 1}: six complete weeks`, grid.length, 42);
  check(`${year}/${month + 1}: correct month length`, grid.filter(day => day.currentMonth).length, length);
  check(`${year}/${month + 1}: first column is Monday`, new Date(grid[0].year, grid[0].month, grid[0].day, 12).getDay(), 1);
  check(`${year}/${month + 1}: today is highlighted exactly once`, grid.filter(day => day.today).map(day => day.day), [15]);
}
const source = fs.readFileSync(path.join(base, "Date.qml"), "utf8");
function method(name, args = "") {
  const pattern = new RegExp("function " + name + "\\(" + args + "\\) \\{([\\s\\S]*?)\\n  \\}");
  const match = source.match(pattern);
  if (!match) throw new Error("Date method missing: " + name);
  return "function " + name + "(" + args + ") {" + match[1] + "}";
}
let pending = false, launches = 0, fallback = [], hasEntry = true;
const c = { calendar: { open: false, resetToToday() {} }, singleClick: { stop() { pending = false; } }, DesktopEntries: { byId(id) { return hasEntry && id === "Calendar" ? { execute() { launches++; } } : null; } }, Quickshell: { execDetached(argv) { fallback.push(argv); } } };
c.root = c;
vm.createContext(c);
// The inline close/open functions are real widget methods as well.
for (const name of ["open", "close", "toggleCalendar"]) {
  const match = source.match(new RegExp("  function " + name + "\\(\\) \\{([^\\n]+)\\}"));
  if (!match) throw new Error("Date method missing: " + name);
  vm.runInContext("function " + name + "() {" + match[1] + "}", c);
}
vm.runInContext(method("openGoogleCalendar"), c);
check("single click is delayed for the configured double-click interval", /interval: Qt\.styleHints\.mouseDoubleClickInterval \+ 20/.test(source), true);
check("single click schedules the timer, rather than opening immediately", /onClicked: singleClick\.restart\(\)/.test(source), true);
check("the single-click timer opens the local calendar", /onTriggered: root\.toggleCalendar\(\)/.test(source), true);
c.toggleCalendar(); check("single click opens calendar", c.calendar.open, true);
c.toggleCalendar(); check("another single click closes calendar", c.calendar.open, false);
pending = true; c.calendar.open = true; c.openGoogleCalendar();
check("double-click cancels the pending single click", pending, false);
check("double-click closes the local calendar", c.calendar.open, false);
check("double-click executes the registered Calendar app once", launches, 1);
hasEntry = false; c.openGoogleCalendar();
check("missing app registration falls back to Google Calendar URL", fallback, [["xdg-open", "https://calendar.google.com/calendar"]]);
const apps = path.join(__dirname, "../../bars/widgets/ruixen.apps");
const group = fs.readFileSync(path.join(apps, "AppGroup.qml"), "utf8");
check("terminal Codex selects the dedicated mark", /codex: "jeebis-codex"/.test(group), true);
check("Codex is no longer mapped to the generic terminal icon", /codex: "utilities-terminal"/.test(group), false);
const runtime = path.join(__dirname, "../../../desktop-runtime/shell/plugins/agents/assets");
const upstreamIcon = fs.readFileSync(path.join(runtime, "codex.svg"), "utf8");
check("blue Codex mark preserves the upstream shape", fs.readFileSync(path.join(apps, "icons/jeebis-codex.svg"), "utf8"), upstreamIcon.replace('fill="#fff"', 'fill="#8cc8ff"'));
check("Codex icon retains the upstream MIT notice", fs.existsSync(path.join(apps, "icons/LICENSE.omarchy")), true);
summary();
