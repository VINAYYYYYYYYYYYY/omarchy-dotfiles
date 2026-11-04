-- A circular order implemented by rotating only at the ends of Hyprland's tape.
-- At an edge, the far column (off-screen) jumps to the other end while animations
-- are paused for ~2 frames, then a normal animated focus step brings it in from
-- the swipe direction. Nothing on screen moves before that step.
local carousel = { pending = nil }
local function layout(message) hl.dispatch(hl.dsp.layout(message)) end
local function focus_window(address) hl.dispatch(hl.dsp.focus({ window = "address:" .. address })) end
local WARP_MS = 34

function carousel.step(direction)
  if direction ~= "l" and direction ~= "r" then return end
  if carousel.pending then return end
  local active = hl.get_active_window()
  local ws = active and active.workspace
  if not ws or ws.tiled_layout ~= "scrolling" or active.floating then
    hl.dispatch(hl.dsp.focus({ direction = direction }))
    return
  end
  local windows = {}
  for _, w in ipairs(hl.get_workspace_windows(ws.id)) do
    if w.mapped and not w.hidden and not w.floating then
      if w.group then layout("focus " .. direction); return end
      table.insert(windows, w)
    end
  end
  table.sort(windows, function(a, b) return a.at.x < b.at.x end)
  if #windows < 2 then return end
  for i = 2, #windows do
    -- Stacked columns retain native behavior; do not reorder individual panes.
    if math.abs(windows[i].at.x - windows[i - 1].at.x) < 2 then
      layout("focus " .. direction); return
    end
  end
  local edge = direction == "l" and windows[1] or windows[#windows]
  if active.address ~= edge.address then layout("focus " .. direction); return end

  -- The column that wraps around to sit next to the active one.
  local far = direction == "l" and windows[#windows] or windows[1]
  local mon = hl.get_active_monitor()
  local left, right = mon.x, mon.x + mon.width / mon.scale
  if far.at.x + far.size.x > left and far.at.x < right then
    -- Whole strip is visible: nothing to hide, just move focus across.
    focus_window(far.address)
    return
  end

  local address, workspace = active.address, ws.id
  local original_x = active.at.x
  local animations = hl.get_config("animations.enabled")
  local follow = hl.get_config("scrolling.follow_focus")
  local function restore()
    hl.config({ animations = { enabled = animations }, scrolling = { follow_focus = follow } })
  end
  local ok, err = pcall(function()
    -- Move only the off-screen far column next to the active one. Animations are
    -- paused so it jumps there instead of sliding across the screen; follow_focus
    -- is off so the brief focus changes don't scroll.
    hl.config({ animations = { enabled = false }, scrolling = { follow_focus = false } })
    focus_window(far.address)
    for _ = 1, #windows - 1 do layout("swapcol " .. direction) end
    focus_window(address)
    local shifted = hl.get_window("address:" .. address)
    if shifted and shifted.at.x ~= original_x then
      layout("move " .. tostring(original_x - shifted.at.x))
    end
    hl.config({ scrolling = { follow_focus = follow } })
  end)
  if not ok then restore(); error(err) end
  -- Let the compositor render the jump (about two frames) before sliding.
  carousel.pending = hl.timer(function()
    carousel.pending = nil
    restore()
    -- Hover may have grabbed focus during the jump; only cancel if the user left
    -- the workspace.
    local current = hl.get_active_workspace()
    if current and current.id == workspace then
      -- Focus by address: the layout's own notion of the current column is stale here.
      focus_window(far.address)
    end
  end, { timeout = WARP_MS, type = "oneshot" })
end
return carousel
