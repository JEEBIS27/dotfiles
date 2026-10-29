// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
function eventTrigger(name) {
  return ({openwindow: "app_open", closewindow: "app_close", workspace: "workspace", workspacev2: "workspace"})[name] || "";
}
function enabled(settings, name, modeTarget) {
  if (!settings || !Object.prototype.hasOwnProperty.call(settings, name)) return false;
  var value = settings[name];
  if (value === "notch") value = "islands"; // Compatibility with the previous name.
  return value === "both" || (value === modeTarget && (value === "bar" || value === "islands"));
}
function lowBattery(value, threshold) {
  return !!value && value.present === true && !value.charging && isFinite(value.percent)
    && value.percent >= 0 && value.percent <= threshold;
}
function changed(channel, previous, value, threshold) {
  if (previous === null || previous === undefined || value === null || value === undefined) return "";
  if (channel === "battery") return lowBattery(value, threshold) && !lowBattery(previous, threshold) ? "low_battery" : "";
  if (channel === "network") return previous !== value ? (value ? "network_reconnect" : "network_disconnect") : "";
  if (channel === "audio") {
    // Device enumeration/replacement establishes a new baseline, not a volume change.
    if (previous.sink !== value.sink) return "";
    return previous.muted !== value.muted || Math.abs(previous.volume - value.volume) > 0.0001 ? "volume_change" : "";
  }
  if (channel === "agent") return !previous && value ? "agent_limit" : "";
  return "";
}
function exhausted(record, now) {
  if (!record || record.ready === false || !Array.isArray(record.limits)) return null;
  return record.limits.some(function(limit) {
    var percent = Number(limit.percent), reset = Date.parse(limit.resetsAt);
    return isFinite(percent) && percent >= 1 && (!isFinite(reset) || reset > now);
  });
}
