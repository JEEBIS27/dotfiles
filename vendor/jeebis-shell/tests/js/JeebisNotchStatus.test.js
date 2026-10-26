// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
// Exercise the actual tooltip and menu handlers, not a copy of their logic.
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const { check, summary } = require("./harness");
const source = fs.readFileSync(path.join(__dirname, "../../bars/widgets/ruixen.notch/NotchStatus.qml"), "utf8");
function body(pattern) {
  const match = source.match(pattern);
  if (!match) throw new Error("Notch status handler is missing: " + pattern);
  return match[1];
}
const context = {
  hoverTarget: "", tooltipText: "", displayedTooltipText: "", activeMenu: "",
  clock: { date: new Date("2026-10-24T12:34:56Z") },
  Qt: { formatDateTime: (_date, format) => format },
  wired: false, network: { signalStrength: 0.73 },
  batteryPercent: 27, charging: false, unreadCount: 3, dnd: false,
  volumePercent: 65, muted: false
};
context.root = context;
vm.createContext(context);
vm.runInContext(
  "function readTooltip() {" + body(/readonly property string tooltipText: \{([\s\S]*?)\n  \}/) + "}\n" +
  "function updateLabel() {" + body(/onTooltipTextChanged: \{([\s\S]*?)\n  \}/) + "}\n" +
  "function openMenu(id) {" + body(/function openMenu\(id\) \{([\s\S]*?)\n  \}/) + "}", context);
function hover(target) {
  context.hoverTarget = target;
  context.tooltipText = context.readTooltip();
  context.updateLabel();
  return context.tooltipText;
}
check("no hover has no tooltip", hover(""), "");
check("clock format includes seconds and timezone name, without UTC offset", hover("clock"), "yyyy-MM-dd HH:mm:ss t");
const clockText = context.displayedTooltipText;
check("leaving the clock hides its tooltip", hover(""), "");
check("leaving keeps the last label so the centered popup cannot shrink before hiding", context.displayedTooltipText, clockText);
check("Wi-Fi hover reports the measured strength", hover("network"), "Wi-Fi 信号 73%");
context.wired = true;
check("wired network hover reports the connection type", hover("network"), "有線接続");
context.wired = false; context.network = null;
check("disconnected network hover reports its state", hover("network"), "ネットワーク未接続");
check("battery hover reports the measured charge", hover("battery"), "バッテリー 27%");
context.charging = true;
check("charging is included in battery details", hover("battery"), "バッテリー 27%（充電中）");
check("volume hover reports the measured level", hover("volume"), "音量 65%");
context.muted = true;
check("muted state is included in volume details", hover("volume"), "音量 65%（ミュート）");
check("notification hover reports unread count", hover("notifications"), "未読通知 3件");
context.dnd = true;
check("DND state is included in notification details", hover("notifications"), "未読通知 3件（消音中）");
const lastLabel = context.displayedTooltipText;
hover("");
check("leaving any status button preserves its last label", context.displayedTooltipText, lastLabel);
for (const [id, menu] of [["omarchy.network", "wifi"], ["omarchy.power", "battery"], ["omarchy.audio", "audio"], ["notifications", "notifications"]]) {
  context.hoverTarget = "clock";
  context.openMenu(id);
  check(`${id}: click opens the corresponding menu`, context.activeMenu, menu);
  check(`${id}: menu opening clears the hover`, context.hoverTarget, "");
  context.openMenu(id);
  check(`${id}: another click closes the menu`, context.activeMenu, "");
}
check("the actual popup label consumes the retained display text", /text: root\.displayedTooltipText/.test(source), true);
check("the actual popup visibility still follows the current hover text", /visible: root\.visible && root\.tooltipText !== "" && root\.hostWindow !== null/.test(source), true);
check("the clock ticks seconds only while its details are requested", /precision: root\.hoverTarget === "clock" \? SystemClock\.Seconds : SystemClock\.Minutes/.test(source), true);
const windowSource = fs.readFileSync(path.join(__dirname, "../../bars/widgets/ruixen.notch/NotchWindow.qml"), "utf8");
check("the collapsed notch hosts the new status strip", /NotchStatus \{[\s\S]*?visible: !panel\.expanded/.test(windowSource), true);
summary();
