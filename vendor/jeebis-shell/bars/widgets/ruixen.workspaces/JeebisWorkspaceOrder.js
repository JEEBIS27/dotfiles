// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
function swapScript(source, target) {
  var a = Number(source), b = Number(target)
  if (!Number.isInteger(a) || !Number.isInteger(b) || a < 1 || b < 1 || a === b) return ""
  return 'local a,b=' + a + ',' + b + '; local focused=hl.get_active_workspace(); local focusedId=focused and focused.id; local moves={}; '
    + 'local function hex(n) local result=""; for c in tostring(n):gmatch(".") do result=result..string.format("%02x",string.byte(c)) end; return result end; '
    + 'local ta,tb="jeebis-float-home-"..hex(a),"jeebis-float-home-"..hex(b); '
    + 'for _,w in ipairs(hl.get_windows({mapped=true})) do '
    + 'local dest=nil; local parked=false; for _,tag in ipairs(w.tags or {}) do if tag==ta then dest=b;parked=true elseif tag==tb then dest=a;parked=true end end; '
    + 'if not dest and w.workspace then if w.workspace.id==a then dest=b elseif w.workspace.id==b then dest=a end end; '
    + 'if dest then moves[#moves+1]={w=w,dest=dest,parked=parked} end end; '
    + 'for _,m in ipairs(moves) do local dest=tostring(m.dest); if m.parked then '
    + 'hl.dispatch(hl.dsp.window.tag({window=m.w,tag="-"..(m.dest==a and tb or ta)})); '
    + 'hl.dispatch(hl.dsp.window.tag({window=m.w,tag="+jeebis-float-home-"..hex(m.dest)})); dest="special:jeebis-floats-"..hex(m.dest) end; '
    + 'hl.dispatch(hl.dsp.window.move({window=m.w,workspace=dest,follow=false})) end; '
    + 'if focusedId==a or focusedId==b then hl.dispatch(hl.dsp.focus({workspace=tostring(focusedId==a and b or a)})) end'
}
