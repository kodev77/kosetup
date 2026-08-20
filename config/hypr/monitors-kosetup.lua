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

-- Laptop panels mirror whichever external is attached (inert on desktops: no eDP)
hl.monitor({ output = "eDP-2", mode = "2560x1600@240", position = "0x0", scale = 1.6, mirror = "desc:ViewSonic Corporation VX3276 Series" })
hl.monitor({ output = "eDP-1", mode = "2880x1800@60", position = "0x0", scale = 2, mirror = "desc:LG Electronics LG ULTRAGEAR" })

-- No fallback line here: omarchy's default monitors.lua already declares
-- `monitor = , preferred, auto, auto` for anything unlisted.

-- --- laptop panel: dark whenever a real external is attached ------------------
-- MacBookPro11,4: with an external connected the external is the ONLY lit
-- display; unplug it and the built-in retina panel comes back on its own.
--
-- THREE THINGS THIS HAD TO WORK AROUND (all measured on 0.56.2 -- see git log):
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
-- Because #2 forces a name selector and every ko laptop calls its panel
-- eDP-1 -- the very collision that made this MacBook inherit the LG machine's
-- mirror rule above -- the block is gated on the DMI product name instead.
-- That keeps it inert on every other machine, the same contract the desc:
-- rules above provide.

local function first_line(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local l = f:read("*l")
  f:close()
  return l
end

local function is_macbook()
  return (first_line("/sys/class/dmi/id/product_name") or ""):match("^MacBook") ~= nil
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

if is_macbook() then
  local panel = panel_output()
  if panel then
    if external_connected() then
      hl.monitor({ output = panel, disabled = true })
    else
      -- Full spec on the way back: a bare disabled=false carries no mode, so
      -- the panel would return undriven. preferred/auto keeps it generic.
      hl.monitor({ output = panel, mode = "preferred", position = "auto", scale = 2 })
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
