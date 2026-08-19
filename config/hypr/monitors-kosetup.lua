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
