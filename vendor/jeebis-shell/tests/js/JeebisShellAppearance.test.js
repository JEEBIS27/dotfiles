// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
// Execute the real configuration/helper code against different user settings.
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const { check, summary } = require("./harness");
const repo = path.join(__dirname, "..", "..");
const config = {};
vm.createContext(config);
vm.runInContext(fs.readFileSync(path.join(repo, "ShellConfig.js"), "utf8").replace(/^\.pragma library\s*/, ""), config);
Object.assign(config, { islandTop: 3, islandHeight: 28, barBottomGap: 4, notchBottomOffset: 0 });
for (const scale of [1, 1.5, 2, 3]) {
  const style = { space: n => n * scale };
  check(`scale ${scale}: painted island top stays at the configured 3px`, config.barTopInset(style) + style.space(2) / 2, 3);
  check(`scale ${scale}: row leaves the requested 28px for the island`, config.barRowHeight(style) - style.space(2), 28);
  check(`scale ${scale}: aligned notch bottom is 31px`, config.collapsedBottom(style), 31);
  check(`scale ${scale}: reserved area includes the 4px window gap`, config.reservedHeight(style), 35);
}
const style = { space: n => n };
config.notchBottomOffset = 10;
check("a notch extending 10px below the islands reserves 45px", config.reservedHeight(style), 45);
config.notchBottomOffset = -7;
check("a shallower notch still leaves space for the 31px island bottom", config.reservedHeight(style), 35);
config.islandHeight = 52;
config.notchBottomOffset = 0;
check("changing island height moves the aligned notch bottom", config.collapsedBottom(style), 55);
check("changing island height updates the window reservation", config.reservedHeight(style), 59);

const bar = fs.readFileSync(path.join(repo, "bars/v2/ruixen.bar/Bar.qml"), "utf8");
const helper = bar.match(/  function surfaceFillForMaterial\(surface, material\) \{[\s\S]*?\n  \}/);
if (!helper) throw new Error("Bar surface material helper is missing");
const surface = { Qt: { rgba: (r, g, b, a) => ({ r, g, b, a }) } };
vm.createContext(surface);
vm.runInContext(helper[0], surface);
for (const color of [{ r: 0.05, g: 0.3, b: 0.8, a: 1 }, { r: 1, g: 0.9, b: 0.6, a: 0.4 }]) {
  const glass = surface.surfaceFillForMaterial(color, "glass");
  check("glass preserves the selected surface RGB", [glass.r, glass.g, glass.b], [color.r, color.g, color.b]);
  check("glass remains translucent without pinning a user's opacity value", Number.isFinite(glass.a) && glass.a > 0 && glass.a < 1, true);
  check("solid preserves the original surface including alpha", surface.surfaceFillForMaterial(color, "solid"), color);
}

// Evaluate the real island width and toggle-margin expressions together.
// A hardcoded 8px toggle margin would pass at padding=8, but not at 3/6/14.
const panel = fs.readFileSync(path.join(repo, "bars/v2/ruixen.bar/BarPanel.qml"), "utf8");
const pinIsland = panel.match(/id: pluginPinsPill\n([\s\S]*?)\n        ModuleList/);
const pinToggle = panel.match(/id: pluginPinsToggle\n([\s\S]*?)\n          anchors.verticalCenter/);
if (!pinIsland || !pinToggle) throw new Error("Plugin pin island layout is missing");
const widthExpression = pinIsland[1].match(/^\s*width: (.+)$/m);
const marginExpression = pinToggle[1].match(/^\s*anchors.rightMargin: (.+)$/m);
if (!widthExpression || !marginExpression) throw new Error("Plugin pin island padding bindings are missing");
for (const padding of [3, 6, 14]) {
  for (const toggleWidth of [0, 20]) {
    for (const contentWidth of [0, 80]) {
      const layout = { ShellConfig: { islandPadding: padding }, pluginPinsContent: { width: contentWidth }, pluginPinsToggle: { implicitWidth: toggleWidth } };
      const width = vm.runInNewContext(widthExpression[1], layout);
      const right = vm.runInNewContext(marginExpression[1], layout);
      const left = width - right - toggleWidth - contentWidth;
      check(`pin island: padding ${padding}, toggle ${toggleWidth}, content ${contentWidth} stays symmetric`, [left, right], [padding, padding]);
    }
  }
}
summary();
