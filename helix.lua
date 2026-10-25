-- HELIX: 3-Layer DNA Sequencer for LIVEN Ambient Ø (MIDI CC Configurable)
-- Helix 1 -> MIDI ch 1
-- Helix 2 -> MIDI ch 2
-- Helix 3 -> MIDI ch 3
-- Internal Engine: Ambient Drone Only
--
-- E1: Continuous Master Tempo (Helix2 & 3 follow Helix1)
-- E2: Harmonic Scale Shift (NOTE)
-- E3: Phase Drift (DRIFT)
-- K3: Select Helix (Helix1 -> Helix2 -> Helix3)
-- K2: Start / Stop Selected Helix (Helix1 triggers Drone Buildup)
-- K1 + E2: Change Root Key (C ~ B)
-- K1 + K2: Smooth Sync to Helix1
-- K1 + K3: Mutation (Shuffle DNA)

engine.name = "Helix"

local BASE_NAMES = {"A", "T", "G", "C"}
local COMPLEMENT = {2, 1, 4, 3}

local KEY_NAMES = {"C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"}
local root_key = 0

local PENTATONIC = {
  36, 41, 43, 48, 51,
  53, 55, 58, 60, 63,
  65, 67, 70, 72, 75,
  77, 79, 82, 84, 87,
  89, 91, 94, 96, 99, 103
}

local HELIX_DIV_NAMES = {"1/4", "1/2", "1/2"}
local HELIX_RATES     = {1.0,   0.5,   0.5  }
local HELIX_SPACINGS  = {30,    38,    38   }

local SEQ_LEN = 16
local selected_helix = 1
local read_head_x = 64
local base_speed = 0.85
local trigger_flash = 0
local k1_held = false

local midi_out = nil
local midi_channel_offset = 0

local helixes = {}
local drone_buildup = 0.0
local current_drone_amp = 0.0
local particles = {}
local cc_throttle_timer = 0

local function midi_to_hz(note)
  return 440.0 * (2 ^ ((note - 69) / 12.0))
end

local function get_helix_note(h_idx, base_idx, degree_offset)
  local intervals = {0, 3, 2, 4}
  local offset = degree_offset or 0
  local note_idx = util.clamp(helixes[h_idx].scale_offset + intervals[base_idx] + offset, 1, #PENTATONIC)
  return PENTATONIC[note_idx]
end

local function update_drone_pitch()
  local root_note = PENTATONIC[helixes[1].scale_offset] + root_key - 24
  engine.drone_hz(midi_to_hz(root_note))
end

local function mutate_helix(h_idx)
  for i = 1, SEQ_LEN do
    helixes[h_idx].seq[i] = math.random(1, 4)
  end
end

-- Send MIDI note (Note On -> Note Off after duration)
local function send_midi_note(ch, note, vel, duration)
  if midi_out then
    local target_ch = util.clamp(ch + midi_channel_offset, 1, 16)
    midi_out:note_on(note, vel, target_ch)
    clock.run(function()
      clock.sleep(duration)
      midi_out:note_off(note, 0, target_ch)
    end)
  end
end

-- Voice trigger function (send to MIDI ch 1..3 & internal engine if enabled)
local function trigger_sound(h_idx, base_idx, pan, octave_shift, amp, release, deg_off)
  local note = get_helix_note(h_idx, base_idx, deg_off) + root_key + (octave_shift * 12)
  note = util.clamp(note, 0, 127)

  local vel = util.clamp(math.floor(amp * 127 * 1.5), 1, 127)
  local duration = math.max(0.04, release * 0.75)

  -- 1. Send to external synth: Helix1 -> ch1, Helix2 -> ch2, Helix3 -> ch3
  send_midi_note(h_idx, note, vel, duration)

  -- 2. Internal pluck voice (played simultaneously only if enabled in PARAMS menu)
  if params:get("internal_voice") == 2 then
    local hz = midi_to_hz(note)
    engine.play(hz, amp, release, pan)
  end
end

local function spawn_particles(x, y, count)
  for p = 1, count do
    table.insert(particles, {
      x = x,
      y = y + math.random(-8, 8),
      vx = -math.random(12, 38) * 0.1,
      vy = math.random(-18, 18) * 0.1,
      life = math.random(14, 30)
    })
  end
end

-- Burst arpeggio (with MIDI output support)
local function trigger_burst_arpeggio(h_idx, b_base)
  clock.run(function()
    local is_long_burst = (math.random() < 0.05)
    local burst_count = is_long_burst and math.random(9, 13) or math.random(4, 6)

    local pan_dir = (math.random() > 0.5) and 1 or -1
    for step = 1, burst_count do
      clock.sleep(math.random(32, 58) * 0.001)
      local pan = (step / burst_count) * 1.5 * pan_dir - (0.75 * pan_dir)
      local oct = (step >= 8) and 3 or ((step >= 4) and 2 or 1)
      local deg_shift = (step % 2 == 0) and 2 or 4
      trigger_sound(h_idx, b_base, pan, oct, is_long_burst and 0.38 or 0.30, 0.22, deg_shift)
    end
  end)
end

-- Automatic configurable CC transmission linked with drone buildup
local function send_ambient0_cc()
  if midi_out and params:get("ambient0_cc") == 2 then
    local cutoff_cc  = math.floor(util.linlin(0, 1, 45, 118, drone_buildup))
    local release_cc = math.floor(util.linlin(0, 1, 35, 110, drone_buildup))
    local shimmer_cc = math.floor(util.linlin(0, 1, 10, 95, drone_buildup))

    local cc1 = params:get("cc1_num")
    local cc2 = params:get("cc2_num")
    local cc3 = params:get("cc3_num")

    for ch = 1, 3 do
      local target_ch = ch + midi_channel_offset
      midi_out:cc(cc1, cutoff_cc, target_ch)
      midi_out:cc(cc2, release_cc, target_ch)
      midi_out:cc(cc3, shimmer_cc, target_ch)
    end
  end
end

function init()
  math.randomseed(os.time())

  -- MIDI Setup
  params:add_separator("midi_header", "MIDI Setup")
  params:add{
    type = "number",
    id = "midi_dev",
    name = "MIDI Device",
    min = 1,
    max = 16,
    default = 1,
    action = function(v)
      midi_out = midi.connect(v)
    end
  }

  params:add{
    type = "option",
    id = "ambient0_cc",
    name = "Drone CC Sync",
    options = {"Off", "On"},
    default = 2
  }

  -- Configurable CC Numbers
  params:add{
    type = "number",
    id = "cc1_num",
    name = "CC 1 Number (Filter)",
    min = 0,
    max = 127,
    default = 38
  }

  params:add{
    type = "number",
    id = "cc2_num",
    name = "CC 2 Number (Release)",
    min = 0,
    max = 127,
    default = 41
  }

  params:add{
    type = "number",
    id = "cc3_num",
    name = "CC 3 Number (Shimmer)",
    min = 0,
    max = 127,
    default = 55
  }

  params:add{
    type = "option",
    id = "internal_voice",
    name = "Internal Pluck Voice",
    options = {"Off (MIDI Only)", "On (Dual)"},
    default = 1
  }

  params:add_separator("helix_settings", "Helix")
  params:add{
    type = "option",
    id = "root_key",
    name = "Root Key",
    options = KEY_NAMES,
    default = 1,
    action = function(v)
      root_key = v - 1
      update_drone_pitch()
    end
  }

  midi_out = midi.connect(params:get("midi_dev"))

  local initial_offsets = {4, 7, 10}
  local radii = {19, 13, 8}

  for i = 1, 3 do
    helixes[i] = {
      active = false,
      fade = 0.0,
      seq = {},
      scale_offset = initial_offsets[i],
      drift = 0.0,
      is_syncing = false,
      scroll_x = 0.0,
      rot_angle = (i - 1) * 0.8,
      base_radius = radii[i],
      radius = radii[i],
      prev_pos = {}
    }
    mutate_helix(i)
  end

  update_drone_pitch()
  engine.drone_amp(0.0)

  local frame_metro = metro.init()
  frame_metro.time = 1 / 40
  frame_metro.event = update_and_render
  frame_metro:start()
end

-- ========================================================
-- Animation & Physical Triggers & Drone Integration
-- ========================================================
function update_and_render()
  if trigger_flash > 0 then trigger_flash = trigger_flash - 1 end

  -- Drone buildup
  if helixes[1].active then
    if drone_buildup < 1.0 then
      drone_buildup = math.min(1.0, drone_buildup + 0.00045)
    end
  else
    if drone_buildup > 0.0 then
      drone_buildup = math.max(0.0, drone_buildup - 0.003)
    end
  end

  engine.cutoff(2200 + (drone_buildup * 7200))

  -- Throttle periodic CC transmission (~every 0.1s)
  cc_throttle_timer = cc_throttle_timer + 1
  if cc_throttle_timer >= 4 then
    cc_throttle_timer = 0
    send_ambient0_cc()
  end

  -- Update particles
  for idx = #particles, 1, -1 do
    local p = particles[idx]
    p.x = p.x + p.vx
    p.y = p.y + p.vy
    p.life = p.life - 1
    if p.life <= 0 or p.x < 0 then
      table.remove(particles, idx)
    end
  end

  local max_fade = 0.0

  for i = 1, 3 do
    local h = helixes[i]

    if h.active and h.fade < 1.0 then
      h.fade = math.min(1.0, h.fade + 0.008)
    elseif not h.active and h.fade > 0.0 then
      h.fade = math.max(0.0, h.fade - 0.012)
    end

    if h.fade > max_fade then
      max_fade = h.fade
    end

    h.radius = h.base_radius * (1.0 + (drone_buildup * 0.35))

    if h.fade > 0.0 then
      if h.is_syncing then
        h.drift = h.drift * 0.94
        if math.abs(h.drift) < 0.002 then
          h.drift = 0.0
          h.is_syncing = false
        end
      end

      local smooth_motion = h.fade * h.fade * (3.0 - (2.0 * h.fade))
      local rate = HELIX_RATES[i]
      local current_speed = base_speed * rate * (1.0 + h.drift) * smooth_motion
      local rot_speed = 0.045 * rate * (1.0 + h.drift) * smooth_motion

      h.scroll_x = h.scroll_x + current_speed
      h.rot_angle = h.rot_angle + rot_speed

      local spacing = HELIX_SPACINGS[i]
      local start_i = math.floor((h.scroll_x - 30) / spacing)
      local end_i = start_i + 8

      for step = start_i, end_i do
        local curr_x = (step * spacing) - h.scroll_x
        local prev_x = h.prev_pos[step] or (curr_x + current_speed)

        if current_speed > 0.01 and prev_x >= read_head_x and curr_x < read_head_x then
          local seq_i = (math.abs(step) % SEQ_LEN) + 1
          local b_top = h.seq[seq_i]
          local b_bot = COMPLEMENT[b_top]

          trigger_flash = (drone_buildup > 0.7) and 4 or 2

          local pan_val = (i == 1) and 0.65 or ((i == 2) and 0.4 or 0.2)
          local base_amp = (i == 1) and 0.48 or ((i == 2) and 0.36 or 0.25)
          local amp_val = base_amp * h.fade

          local rel_mult = (i == 1 and 1.0 or 1.5) * (1.0 + drone_buildup * 1.6)
          local rel_val = ((i == 1) and 0.65 or ((i == 2) and 0.35 or 0.16)) * rel_mult

          -- Trigger base pair (2 notes) with MIDI output
          trigger_sound(i, b_top, -pan_val, (i == 1) and 0 or 1, amp_val, rel_val)
          trigger_sound(i, b_bot,  pan_val, (i == 1) and -2 or -1, amp_val, rel_val)

          -- Polyphony expansion during drone buildup
          if drone_buildup > 0.50 then
            trigger_sound(i, b_top, 0.0, 0, amp_val * 0.7, rel_val * 0.8, 2)
            if drone_buildup > 0.80 then
              trigger_sound(i, b_bot, (math.random() > 0.5 and 0.45 or -0.45), 1, amp_val * 0.6, rel_val * 0.6, 4)
            end
          end

          -- Burst arpeggio during drone buildup
          if drone_buildup > 0.45 then
            local burst_chance = util.linlin(0.45, 1.0, 0.20, 0.80, drone_buildup)
            if math.random() < burst_chance then
              trigger_burst_arpeggio(i, b_top)
              spawn_particles(read_head_x, 32, (math.random() < 0.05 and 20 or 7))
            end
          end
        end
        h.prev_pos[step] = curr_x
      end
    end
  end

  -- Send drone volume (norns built-in SuperCollider)
  local target_drone_amp = max_fade * drone_buildup * 0.85
  if math.abs(current_drone_amp - target_drone_amp) > 0.005 then
    current_drone_amp = target_drone_amp
    engine.drone_amp(current_drone_amp)
  end

  redraw()
end

-- ========================================================
-- Encoder & Key Operations
-- ========================================================
function enc(n, d)
  if k1_held then
    if n == 2 then
      root_key = (root_key + d) % 12
      params:set("root_key", root_key + 1)
      update_drone_pitch()
    end
  else
    local h = helixes[selected_helix]
    if n == 1 then
      base_speed = util.clamp(base_speed + (d * 0.03), 0.2, 2.5)
    elseif n == 2 then
      h.scale_offset = util.clamp(h.scale_offset + d, 1, #PENTATONIC - 6)
      if selected_helix == 1 then
        update_drone_pitch()
      end
    elseif n == 3 then
      h.drift = util.clamp(h.drift + (d * 0.015), -0.35, 0.35)
      h.is_syncing = false
    end
  end
end

function key(n, z)
  if n == 1 then
    k1_held = (z == 1)
    redraw()
  elseif z == 1 then
    if n == 2 then
      if k1_held then
        if selected_helix > 1 then
          helixes[selected_helix].is_syncing = true
        else
          for i = 2, 3 do helixes[i].is_syncing = true end
        end
      else
        local h = helixes[selected_helix]
        h.active = not h.active
        if h.active and h.fade == 0.0 then
          h.prev_pos = {}
          if selected_helix == 1 then
            drone_buildup = 0.0
          end
        end
      end
    elseif n == 3 then
      if k1_held then
        for i = 1, 3 do mutate_helix(i) end
      else
        selected_helix = (selected_helix % 3) + 1
      end
    end
  end
end

-- ========================================================
-- 3D Spatial Rendering
-- ========================================================
function redraw()
  screen.clear()
  screen.font_size(8)

  local cy = 32
  local twist_rate = 0.042
  local any_visible = false

  local function draw_helix(h_idx)
    local h = helixes[h_idx]
    if h.fade <= 0.01 then return end
    any_visible = true

    local is_sel = (h_idx == selected_helix)
    local spacing = HELIX_SPACINGS[h_idx]
    local fade = h.fade

    local function get_y(x, s_idx)
      local ang = ((x + h.scroll_x) * twist_rate) + h.rot_angle + (s_idx * math.pi)
      return cy + (math.sin(ang) * h.radius)
    end

    -- 1. Background ribbon
    local bg_lvl = math.floor((is_sel and 3 or 1) * fade)
    if bg_lvl >= 1 then
      for s = 0, 1 do
        local s_ang = s * math.pi
        for x = 0, 127, (h_idx == 3 and 2 or 1) do
          local ang = ((x + h.scroll_x) * twist_rate) + h.rot_angle + s_ang
          if math.cos(ang) < 0 then
            screen.level(bg_lvl)
            screen.pixel(x, math.floor(cy + math.sin(ang) * h.radius))
            screen.fill()
          end
        end
      end
    end

    -- 2. Base pair blocks
    local start_i = math.floor((h.scroll_x - 30) / spacing)
    local end_i = start_i + 8
    local bars = {}

    for i = start_i, end_i do
      local x = (i * spacing) - h.scroll_x
      if x >= -12 and x <= 140 then
        local ang = ((x + h.scroll_x) * twist_rate) + h.rot_angle
        local seq_i = (math.abs(i) % SEQ_LEN) + 1
        table.insert(bars, {
          x = x,
          cos = math.cos(ang),
          b_top = h.seq[seq_i],
          b_bot = COMPLEMENT[h.seq[seq_i]]
        })
      end
    end
    table.sort(bars, function(a, b) return a.cos < b.cos end)

    for _, bar in ipairs(bars) do
      local x = math.floor(bar.x)
      local z = bar.cos
      local raw_bright = is_sel 
        and util.linlin(-1, 1, 4, 15, z)
        or  util.linlin(-1, 1, 2, 7, z)
      local bright = math.floor(raw_bright * fade)

      if bright >= 1 then
        screen.level(bright)

        local hw = (h_idx == 1) and ((z > 0) and 3 or 2) or ((h_idx == 2) and 2 or 1)
        local xl, xr = x - hw, x + hw
        local y_top_l = get_y(xl, 0)
        local y_top_r = get_y(xr, 0)
        local y_bot_l = get_y(xl, 1)
        local y_bot_r = get_y(xr, 1)

        if y_top_l > y_bot_l then
          y_top_l, y_bot_l = y_bot_l, y_top_l
          y_top_r, y_bot_r = y_bot_r, y_top_r
        end

        local gap = (h_idx == 1) and 6 or ((h_idx == 2) and 4 or 2)
        local y_mid_top = cy - gap
        local y_mid_bot = cy + gap

        if (y_mid_top - math.min(y_top_l, y_top_r)) > 1 then
          screen.move(xl, math.floor(y_top_l))
          screen.line(xr, math.floor(y_top_r))
          screen.line(xr, math.floor(y_mid_top))
          screen.line(xl, math.floor(y_mid_top))
          screen.close()
          screen.stroke()

          if is_sel and h_idx <= 2 and bright >= 5 and (y_mid_top - y_top_l) >= 7 then
            screen.move(xl + 1, math.floor(y_mid_top - 2))
            screen.text(BASE_NAMES[bar.b_top])
          end
        end

        if (math.max(y_bot_l, y_bot_r) - y_mid_bot) > 1 then
          screen.move(xl, math.floor(y_mid_bot))
          screen.line(xr, math.floor(y_mid_bot))
          screen.line(xr, math.floor(y_bot_r))
          screen.line(xl, math.floor(y_bot_l))
          screen.close()
          screen.stroke()

          if is_sel and h_idx <= 2 and bright >= 5 and (y_bot_l - y_mid_bot) >= 7 then
            screen.move(xl + 1, math.floor(y_mid_bot + 7))
            screen.text(BASE_NAMES[bar.b_bot])
          end
        end
      end
    end

    -- 3. Foreground ribbon
    for s = 0, 1 do
      local s_ang = s * math.pi
      for x = 0, 127 do
        local ang = ((x + h.scroll_x) * twist_rate) + h.rot_angle + s_ang
        local z = math.cos(ang)
        if z >= 0 then
          local raw_rb = is_sel 
            and util.linlin(0, 1, 8, 15, z)
            or  util.linlin(0, 1, 4, 9, z)
          local rb = math.floor(raw_rb * fade)
          if rb >= 1 then
            screen.level(rb)
            local thick = (h_idx == 1) and 3 or ((h_idx == 2) and 2 or 1)
            screen.rect(x, math.floor(cy + math.sin(ang) * h.radius) - 1, 1, thick)
            screen.fill()
          end
        end
      end
    end
  end

  for i = 3, 1, -1 do
    if i ~= selected_helix then draw_helix(i) end
  end
  draw_helix(selected_helix)

  -- 4. Particles
  for _, p in ipairs(particles) do
    screen.level(math.floor(util.linlin(0, 30, 2, 15, p.life)))
    screen.pixel(math.floor(p.x), math.floor(p.y))
    screen.fill()
  end

  -- 5. Center read head
  if any_visible then
    local head_lvl = (trigger_flash > 0) and 15 or math.floor(util.linlin(0, 1, 5, 13, drone_buildup))
    screen.level(head_lvl)
    screen.move(read_head_x, 11)
    screen.line(read_head_x, 53)
    screen.stroke()

    if drone_buildup > 0.65 then
      screen.level(math.floor(head_lvl * 0.4))
      screen.move(read_head_x - 1, 12)
      screen.line(read_head_x - 1, 52)
      screen.move(read_head_x + 1, 12)
      screen.line(read_head_x + 1, 52)
      screen.stroke()
    end
  end

  -- Upper UI
  for i = 1, 3 do
    local hx = 4 + (i - 1) * 42
    local h = helixes[i]
    local label = "Helix" .. i

    if i == selected_helix then
      screen.level(15)
      screen.rect(hx - 2, 1, 38, 9)
      screen.fill()
      screen.level(0)
    else
      screen.level(h.active and 10 or 3)
    end
    screen.move(hx, 8)
    screen.text(label)

    if h.active then
      screen.level(i == selected_helix and 0 or 15)
      screen.rect(hx + 32, 3, 2, 2)
      screen.fill()
    end
  end

  -- Lower UI (with MIDI channel display)
  screen.move(4, 62)

  if k1_held then
    screen.level(15)
    screen.text("KEY: [ " .. KEY_NAMES[root_key + 1] .. " ]  (E2 TO CHANGE)")
  else
    local cur = helixes[selected_helix]
    screen.level(cur.active and 12 or 5)

    local state_str = cur.active and "ON" or "OFF"
    local drift_pct = math.floor(cur.drift * 100)
    local drift_str = (drift_pct >= 0 and "+" or "") .. drift_pct .. "%"
    if cur.is_syncing then drift_str = "SYNC~" end

    local tempo_str = string.format("%.2f", base_speed)
    local drone_pct = math.floor(drone_buildup * 100)
    local tag = (drone_buildup > 0.70) and "[SURGE]" or ("~" .. drone_pct .. "%")

    screen.text(state_str .. " " .. HELIX_DIV_NAMES[selected_helix] .. " SPD:" .. tempo_str .. " N:" .. cur.scale_offset .. " >ch" .. selected_helix .. " " .. tag)
  end

  screen.update()
end