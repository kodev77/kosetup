-- kosetup known-monitor rules — symlinked to ~/.config/hypr/monitors-kosetup.lua
-- and pulled in from the user's monitors.lua via a marker block (install.sh
-- display/monitors). Ported from komarchy 000-00004-mnt-hpr.sh.
--
-- SELF-GUARDING: Hyprland ignores monitor rules whose output (name or desc:)
-- is not currently connected, so every rule below is inert on machines that
-- lack that display. desc: matches the description WITHOUT the per-unit
-- serial, so a replacement panel of the same model still matches. This block
-- is therefore safe verbatim on every machine.

-- omarchy's default monitors.lua sets GDK_SCALE=2 (HiDPI laptop assumption).
-- Every known ko setup drives its externals at scale 1, where GDK_SCALE=2
-- doubles XWayland GTK apps — same fix komarchy applied. Loaded after the
-- default, so this wins.
hl.env("GDK_SCALE", "1")

-- ViewSonic 32" 1440p: VX3211-2K (ko-mini-omarchy's display) + the older VX3276
hl.monitor({ output = "desc:ViewSonic Corporation VX3211-2K", mode = "2560x1440@60", position = "0x0", scale = 1 })
hl.monitor({ output = "desc:ViewSonic Corporation VX3276 Series", mode = "2560x1440@60", position = "0x0", scale = 1 })

-- LG ULTRAGEAR 32" 4K, deliberately run at 1440p/scale 1
hl.monitor({ output = "desc:LG Electronics LG ULTRAGEAR", mode = "2560x1440@59.95", position = "0x0", scale = 1 })

-- Laptop panel mirroring its external (inert on desktops: no eDP).
-- eDP-2 (the ROG) was here too, mirroring the VX3276 — the komarchy rule. It is
-- gone: that machine now drives a VX3211-2K, so the mirror target no longer
-- resolves, and the panel-off block below supersedes mirroring for it anyway.
hl.monitor({ output = "eDP-1", mode = "2880x1800@60", position = "0x0", scale = 2, mirror = "desc:LG Electronics LG ULTRAGEAR" })

-- No fallback line here: omarchy's default monitors.lua already declares
-- `monitor = , preferred, auto, auto` for anything unlisted.

-- --- laptop panel: dark whenever a real external is attached ------------------
-- On every laptop listed in PANEL_OFF below: with an external connected the
-- external is the ONLY lit display; unplug it and the built-in panel comes
-- back on its own. Two machines want this — the MacBook, and the ROG, whose
-- external hangs off a KVM and so appears and disappears many times a day.
--
-- FOUR THINGS THIS HAD TO WORK AROUND (all measured on 0.56.2 -- see git log):
--
--  1. hl.monitor() only REGISTERS a rule. Hyprland applies monitor rules when
--     it finishes parsing the config and on a monitor reload -- never at the
--     moment hl.monitor() is called. Calling it from a timer, from an hl.on()
--     callback, or from `hyprctl eval` returns ok and changes nothing. So the
--     decision is made at PARSE time, and hotplug is handled by asking for a
--     reload so a fresh parse can decide again.
--
--  2. A `desc:` selector does NOT work for disabled= -- the rule is accepted,
--     configerrors stays clean, and the panel simply stays on. Only the output
--     NAME disables. (desc: works fine for the mode/position rules above.)
--
--  3. Hyprland parses this config TWICE per reload and hl.get_monitors()
--     reports a different set on each pass, so the panel alternated on/off
--     when the decision read that list. sysfs is the stable ground truth.
--
--  4. The catch-all rule (`output = ""`, omarchy's is in monitors.lua) is
--     applied LAST when a monitor changes state and BEATS the panel rule
--     below, so it -- not this file -- is what sets the panel's scale. Forcing
--     it to a marker value showed the panel come back at this file's scale for
--     about a second, then snap to the catch-all's. What does NOT work, all
--     measured on 0.56.2:
--       * declaring the catch-all in this module instead: ignored outright,
--         the panel falls back to Hyprland's own auto
--       * giving it a computed value in monitors.lua (function call, hoisted
--         local, one line or several): same, ignored
--       * registration order, and a desc: selector on the panel rule
--     Only a LITERAL in monitors.lua holds, so install.sh writes one there
--     (catchall_scale_for_machine) and it must match this machine's scale
--     below. Externals are unaffected: a desc: rule DOES win for a freshly
--     hotplugged monitor -- with the catch-all at the ROG panel's 1.6 the
--     ViewSonic still comes back at its own 1 -- it is only the panel's
--     disabled->enabled path that loses. Nothing caught this before the ROG
--     because "auto" happened to resolve to the wanted value on every other
--     display: ViewSonic 32" 1440p -> 1, retina -> 2.
--
-- Because #2 forces a name selector, and panel names collide across machines
-- -- the MacBook and the LG machine both call theirs eDP-1, the very collision
-- that made the MacBook inherit the LG machine's mirror rule above -- the block
-- is gated on the DMI product name instead. That keeps it inert on every other
-- machine, the same contract the desc: rules above provide. The panel's own
-- connector is still discovered at runtime (the ROG's is eDP-2, not eDP-1), so
-- the DMI entry carries only the restore spec, never the output name.

local function first_line(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local l = f:read("*l")
  f:close()
  return l
end

-- The laptops that want the panel dark under an external, each with the spec
-- that drives it on the way back. Matched against DMI product_name; a machine
-- absent from this table keeps omarchy's stock behaviour untouched.
local PANEL_OFF = {
  -- MacBookPro11,4, panel eDP-1 — preferred/2 keeps the retina restore generic.
  { product = "^MacBook",          mode = "preferred",     scale = 2   },
  -- ROG Zephyrus M16 GU604VI, panel eDP-2 (BOE 2560x1600@240). 1.6 ->
  -- 1600x1000 logical, komarchy's value for this exact panel. Judged at UAT on
  -- the panel itself: omarchy's auto (2 -> 1280x800) too big, 1 (native
  -- 2560x1600) too small. Mirrored in install.sh catchall_scale_for_machine,
  -- which is the copy that actually takes effect (#4).
  { product = "^ROG Zephyrus M16", mode = "2560x1600@240", scale = 1.6 },
}

-- This machine's restore spec, or nil — which doubles as the gate.
local function panel_off_spec()
  local product = first_line("/sys/class/dmi/id/product_name") or ""
  for _, entry in ipairs(PANEL_OFF) do
    if product:match(entry.product) then return entry end
  end
  return nil
end

-- Connector name of the built-in panel, e.g. "eDP-1" (nil if there is none).
local function panel_output()
  local h = io.popen([[
    for s in /sys/class/drm/card*-*/status; do
      c=${s%/status}; c=${c##*/}
      case "$c" in
        *eDP*) [ "$(cat "$s" 2>/dev/null)" = connected ] && { echo "${c#*-}"; break; } ;;
      esac
    done
  ]])
  if not h then return nil end
  local out = (h:read("*a") or ""):gsub("%s+$", "")
  h:close()
  if out == "" then return nil end
  return out
end

-- Is any NON-internal connector plugged in? Read from sysfs, so it is
-- unaffected by which outputs Hyprland has enumerated or already disabled.
local function external_connected()
  local h = io.popen([[
    for s in /sys/class/drm/card*-*/status; do
      c=${s%/status}; c=${c##*/}
      case "$c" in *eDP*) continue ;; esac
      [ "$(cat "$s" 2>/dev/null)" = connected ] && { echo yes; break; }
    done
  ]])
  if not h then return false end
  local out = h:read("*a") or ""
  h:close()
  return out:find("yes", 1, true) ~= nil
end

local panel_spec = panel_off_spec()

if panel_spec then
  local panel = panel_output()
  local ext = external_connected()
  if panel then
    if ext then
      hl.monitor({ output = panel, disabled = true })
    else
      -- Full spec on the way back: a bare disabled=false carries no mode, so
      -- the panel would return undriven. position stays "auto" — with no
      -- external there is nothing to lay it out against. NOTE the scale here
      -- does not actually decide anything (#4): the catch-all install.sh wrote
      -- into monitors.lua overrides it. Keep the two in step.
      hl.monitor({ output = panel, mode = panel_spec.mode, position = "auto", scale = panel_spec.scale })
    end

  end

  -- Hyprland's own view, used only to spot drift from what sysfs calls for.
  local function panel_enabled_now()
    for _, m in ipairs(hl.get_monitors()) do
      if m.name == panel then return true end
    end
    return false
  end

  -- Rate-limit the reconcile reload. The Lua state is rebuilt on every parse,
  -- so an in-memory counter cannot survive to bound a loop -- the stamp can.
  local RELOAD_STAMP = "/tmp/kosetup-panel-reload"
  local function may_reload()
    local now = os.time()
    local f = io.open(RELOAD_STAMP, "r")
    if f then
      local last = tonumber(f:read("*l") or "0") or 0
      f:close()
      if now - last < 5 then return false end
    end
    f = io.open(RELOAD_STAMP, "w")
    if f then f:write(tostring(now)); f:close() end
    return true
  end

  -- A hotplug changes reality but cannot re-run the decision above, so
  -- reconcile by reloading: a plain reload re-parses AND re-applies monitor
  -- rules (`reload config-only` would skip the monitor half). Reloads only on
  -- genuine drift, so a settled machine never reloads and this cannot spin.
  local reconcile_timer
  local function reconcile()
    if external_connected() == panel_enabled_now() and may_reload() then
      hl.exec_cmd("hyprctl reload")
    end
  end

  -- monitor.removed fires while the departing output can still appear in the
  -- list; re-decide on a short one-shot timer so it sees settled state.
  local function reconcile_soon()
    reconcile_timer = hl.timer(reconcile, { timeout = 750, type = "oneshot" })
  end

  hl.on("monitor.added", reconcile_soon)
  hl.on("monitor.removed", reconcile_soon)
end

-- Value for the catch-all rule that install.sh writes into monitors.lua (see
-- #4): the panel's own scale while the panel is the only lit display, and 1
-- once an external is driving -- every ko external runs at scale 1 (GDK_SCALE
-- note at the top). nil on machines this file does not claim, which leaves
-- omarchy's own value in place.
local M = {}

function M.catchall_scale()
  local spec = panel_off_spec()
  if not spec then return nil end
  return external_connected() and 1 or spec.scale
end

return M
