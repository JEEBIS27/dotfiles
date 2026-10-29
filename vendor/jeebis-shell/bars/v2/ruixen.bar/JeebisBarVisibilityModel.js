// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
function modeTarget(value) { return value === "notch" || value === "islands" ? "islands" : "bar"; }
function normalize(value) {
  value = value || {};
  var behavior = ["auto", "always", "off"].indexOf(value.behavior) >= 0 ? value.behavior : "always";
  return { target: modeTarget(value.target), behavior: behavior, reserve: behavior === "always" && value.reserve === true };
}
function next(value, target, fixed) {
  var mode = normalize(value);
  target = modeTarget(target);
  if (fixed) {
    var off = mode.target === target && mode.behavior === "always" && mode.reserve;
    return {target: target, behavior: off ? "off" : "always", reserve: !off};
  }
  return {target: target, behavior: mode.target === target && mode.behavior === "auto" ? "always" : "auto", reserve: false};
}
function isActivity(name) { return ["openwindow", "closewindow", "workspace", "workspacev2"].indexOf(name) >= 0; }
function shown(value, held, activity, bridge) {
  var mode = normalize(value);
  return mode.behavior === "always" || (mode.behavior === "auto" && (held || activity || bridge));
}
function revealSections(target, islandOnly, section) {
  return target === "bar" || !islandOnly ? ["left", "notch", "right"] : [section === "left" || section === "right" ? section : "notch"];
}
function sectionAt(geometry, x) {
  if (!geometry) return "";
  for (var i = 0, keys = ["notch", "left", "right"]; i < keys.length; ++i) {
    var key = keys[i], rect = geometry[key];
    if (rect && rect.width > 0 && x >= rect.x && x <= rect.x + rect.width) return key;
  }
  return "";
}

function sectionBehavior(value, section) {
  var mode = normalize(value);
  return mode.target === "islands" && mode.behavior === "always" && section !== "notch" ? "auto" : mode.behavior;
}
