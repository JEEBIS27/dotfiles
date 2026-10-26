.pragma library
// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
function currentDate() { return new Date() }
function monthDate(year, month) { return new Date(year, month, 1, 12) }
function monthAt(year, month, offset) {
  var date = new Date(year, month + offset, 1, 12)
  return { year: date.getFullYear(), month: date.getMonth() }
}
function monthGrid(year, month, today) {
  var first = new Date(year, month, 1, 12)
  var start = (first.getDay() + 6) % 7 // Monday first.
  var result = []
  for (var i = 0; i < 42; ++i) {
    var date = new Date(year, month, 1 - start + i, 12)
    result.push({
      day: date.getDate(), year: date.getFullYear(), month: date.getMonth(),
      currentMonth: date.getFullYear() === year && date.getMonth() === month,
      today: date.getFullYear() === today.getFullYear() && date.getMonth() === today.getMonth() && date.getDate() === today.getDate()
    })
  }
  return result
}
