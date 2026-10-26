// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
.pragma library
function count(value) { var n = Number(value); return isFinite(n) && n > 0 ? n : 0 }
function format(value) { return Math.round(count(value)).toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ",") }
function parse(text) {
  try { var data = JSON.parse(text); return data && typeof data === "object" && !Array.isArray(data) ? data : null }
  catch (e) { return null }
}
function models(record) {
  var usage = (record && record.modelUsage) || {}, rows = []
  for (var name in usage) {
    var m = usage[name] || {}, input = count(m.inputTokens), output = count(m.outputTokens)
    var read = count(m.cacheReadInputTokens), write = count(m.cacheCreationInputTokens)
    rows.push({name: name, input: input, output: output, cacheRead: read, cacheWrite: write, total: input + output + read + write})
  }
  return rows.sort(function(a,b) { return b.total - a.total })
}
function total(record) { return models(record).reduce(function(sum, row) { return sum + row.total }, 0) }
function days(record) {
  return ((record && record.recentDays) || []).slice().sort(function(a,b) { return String(a.date).localeCompare(String(b.date)) }).slice(-7)
}
