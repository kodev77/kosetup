-- Results window: query output in its own zoomed-out terminal.
--
--   <leader>dw   open / close the results window
--
-- Only on Hyprland with foot (the ROG). Elsewhere (WSL, the Mac) this file
-- does nothing and dadbod shows results in its usual split.
--
-- The first query opens the window by itself. Closing it (<leader>dw, or
-- closing the window) turns that off until <leader>dw opens it again.
--
-- A terminal has one font size, so the dbout split under the query can't be
-- made smaller on its own. Instead this opens a second foot window (zoomed
-- out one ZOOM_STEP, see below) running its own nvim, tiled BELOW the current window at about a
-- third of the height. While it's open:
--   * every finished query shows there, and the dbout split in this nvim is
--     closed so the query keeps the full height;
--   * switching query buffers shows that buffer's last result (dadbod doesn't
--     link a query buffer to its output, so DBExecutePre — fired while the
--     query buffer is current — records which buffer each output file is for).
-- The second nvim loads this same config, so the formatter, expand (<CR>) and
-- toggles work there too. This nvim pushes files to it over a private socket
-- (nvim_exec_lua via rpcnotify). Quitting this nvim closes it.
-- The window opens at foot.ini's normal font size and is then zoomed out one
-- step (Ctrl+minus), so Ctrl+0 brings it back to normal and Ctrl+minus makes
-- it small again. The step is set for this window only: 13 -> 10.
local ZOOM_STEP = 3 -- points per Ctrl+minus / Ctrl+= in the results window
local HEIGHT_PCT = 0.33 -- share of the stack the results window gets

if not (vim.env.HYPRLAND_INSTANCE_SIGNATURE and vim.fn.executable("foot") == 1 and vim.fn.executable("hyprctl") == 1) then
  return {}
end

local S = {
  job = nil, -- foot job id
  chan = nil, -- rpc channel to the results nvim
  sock = nil,
  shown = nil, -- file (or note key) currently shown there
  last = {}, -- query bufnr -> { file =, input = }
  running = {}, -- query bufnr -> { text =, started = } while its query runs
  pending = {}, -- output file -> { qbuf =, input = } (between Pre and Post)
  off = false, -- user closed it: no auto-open until <leader>dw
}

-- Runs inside the results nvim: show `file` as a fresh dbout buffer.
local REMOTE = [[
local file, input = ...
vim.o.cmdheight = 0 -- no empty command-line row under the status bar
-- The dbout FileType hooks (formatter, keys, highlights) live in
-- dadbod-autocmds' config, which only runs once vim-dadbod-ui loads.
pcall(function() require("lazy").load({ plugins = { "vim-dadbod-ui" } }) end)
for _, b in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_get_name(b) == file then
    pcall(vim.api.nvim_buf_delete, b, { force = true })
  end
end
vim.cmd("silent edit " .. vim.fn.fnameescape(file))
-- Drop results no longer on screen so a big one doesn't sit in memory;
-- switching back to it just reads its file again.
local cur = vim.api.nvim_get_current_buf()
for _, b in ipairs(vim.api.nvim_list_bufs()) do
  if b ~= cur and vim.api.nvim_buf_get_name(b):match("%.dbout$") and #vim.fn.win_findbuf(b) == 0 then
    pcall(vim.api.nvim_buf_delete, b, { force = true })
  end
end
if input ~= "" then vim.b.db_input = input end
-- `edit` normally detects dbout already. Setting it a second time re-runs the
-- FileType hook, which resets the formatter's done flag and so hides the
-- sticky header.
if vim.bo.filetype ~= "dbout" then
  vim.bo.filetype = "dbout"
end
vim.defer_fn(function()
  pcall(function() require("util.dadbod-format").finalize_empty() end)
end, 1500)
]]

-- Runs inside the results nvim: show a short note instead of a result (the
-- first-open hint, "no results yet", "running"). With `started` (epoch
-- seconds) the second line gets a live elapsed-seconds count; the timer stops
-- once the note buffer is gone (a result replaced it).
local NOTE = [[
local lines, started = ...
vim.o.cmdheight = 0 -- no empty command-line row under the status bar
if _G.dbout_note_timer then
  pcall(function() _G.dbout_note_timer:stop() _G.dbout_note_timer:close() end)
  _G.dbout_note_timer = nil
end
vim.cmd("enew")
vim.bo.buftype = "nofile"
vim.bo.bufhidden = "wipe"
local buf = vim.api.nvim_get_current_buf()
local function paint()
  local out = vim.deepcopy(lines)
  if started and out[2] then
    out[2] = out[2] .. "  " .. (os.time() - started) .. "s"
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.bo[buf].modifiable = false
end
paint()
if started then
  local t = vim.uv.new_timer()
  _G.dbout_note_timer = t
  t:start(1000, 1000, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      pcall(function() t:stop() t:close() end)
      if _G.dbout_note_timer == t then _G.dbout_note_timer = nil end
      return
    end
    paint()
  end))
end
]]

local IDLE_LINES = { "", "  Results window: run a query (<leader>dr / <leader>dR) and its output shows here." }

-- Omarchy's Hyprland config is Lua, so `hyprctl dispatch` takes a Lua
-- dispatcher expression (hl.dsp...), not the old "dispatcher args" text.
local function hypr(expr)
  pcall(function()
    vim.system({ "hyprctl", "dispatch", expr }):wait(1000)
  end)
end

local function client(addr_or_class)
  local ok, list = pcall(vim.json.decode, vim.fn.system({ "hyprctl", "clients", "-j" }))
  if not ok then
    return nil
  end
  for _, c in ipairs(list) do
    if c.address == addr_or_class or c.class == addr_or_class then
      return c
    end
  end
end

-- Stack the results window under the main one at HEIGHT_PCT of the height.
-- It opens with focus, beside the main window (dwindle splits the wider way):
-- togglesplit turns that into a top/bottom split. The size is then set from
-- the TOP (main) window: a relative resize on the bottom window moves the
-- shared edge the other way and grows it. Focus ends on the main window.
-- A scrolling-layout workspace (Super+L) has no togglesplit: leave the window
-- beside the main one there.
local function place(main_addr)
  local main, res = client(main_addr), client("dbout-results")
  if not (main and res) then
    return
  end
  local ok, ws = pcall(vim.json.decode, vim.fn.system({ "hyprctl", "activeworkspace", "-j" }))
  if ok and type(ws) == "table" and ws.tiledLayout and ws.tiledLayout ~= "dwindle" then
    hypr(string.format('hl.dsp.focus({ window = "address:%s" })', main_addr))
    return
  end
  if res.at[1] ~= main.at[1] then
    hypr(string.format('hl.dsp.focus({ window = "address:%s" })', res.address))
    hypr('hl.dsp.layout("togglesplit")')
    vim.uv.sleep(150) -- let the new geometry land before measuring
    main, res = client(main_addr), client("dbout-results")
  end
  hypr(string.format('hl.dsp.focus({ window = "address:%s" })', main_addr))
  if main and res then
    local target = math.floor((main.size[2] + res.size[2]) * (1 - HEIGHT_PCT))
    hypr(string.format("hl.dsp.window.resize({ x = 0, y = %d, relative = true })", target - main.size[2]))
  end
end

local function is_open()
  return S.chan ~= nil
end

-- Open, or still starting up (results then go there once it connects).
local function active()
  return S.chan ~= nil or S.job ~= nil
end

local function push(entry, force)
  if not is_open() or not entry then
    return
  end
  if not force and S.shown == entry.file then
    return
  end
  local ok = pcall(vim.rpcnotify, S.chan, "nvim_exec_lua", REMOTE, { entry.file, entry.input or "" })
  if ok then
    S.shown = entry.file
  end
end

local function note(key, lines, started)
  if not is_open() then
    return
  end
  if pcall(vim.rpcnotify, S.chan, "nvim_exec_lua", NOTE, { lines, started or vim.NIL }) then
    S.shown = key
  end
end

-- A query buffer: one dadbod / DBUI runs queries from (not the DBUI sidebar,
-- neo-tree or a plain code file).
local function is_query_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  local ft = vim.bo[buf].filetype
  if ft == "dbui" or ft == "dbout" then
    return false
  end
  return vim.b[buf].db ~= nil or vim.b[buf].dbui_db_key_name ~= nil or ft == "sql" or ft == "mysql" or ft == "plsql"
end

-- What the results window shows for query buffer `buf`: "running" while its
-- query runs, else its last result, else a "no results yet" note. Any other
-- buffer leaves the window as it is.
local function show(buf, force)
  local run = S.running[buf]
  if run then
    local key = "running:" .. buf
    if force or S.shown ~= key then
      note(key, { "", "  Running: " .. run.text }, run.started)
    end
  elseif S.last[buf] then
    push(S.last[buf], force)
  elseif is_query_buf(buf) then
    local key = "none:" .. buf
    if force or S.shown ~= key then
      local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
      note(key, { "", "  No results yet for " .. (name ~= "" and name or "this query") .. ".",
        "  Run it with <leader>dr and its output shows here." })
    end
  else
    return false
  end
  return true
end

-- Close this nvim's own dbout windows (the results window has the output).
local function close_local_dbout()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "dbout" and #vim.api.nvim_list_wins() > 1 then
      pcall(vim.api.nvim_win_close, win, false)
    end
  end
end

local function reset()
  if S.chan then
    pcall(vim.fn.chanclose, S.chan)
  end
  S.job, S.chan, S.shown = nil, nil, nil
  if S.sock then
    os.remove(S.sock)
  end
end

local function close()
  if S.chan then
    pcall(vim.rpcnotify, S.chan, "nvim_command", "qa!")
  elseif S.job then
    pcall(vim.fn.jobstop, S.job) -- still starting up
  end
  reset()
end

local function open()
  S.sock = vim.fn.stdpath("run") .. "/dbout-results-" .. vim.fn.getpid() .. ".sock"
  os.remove(S.sock)
  local main = vim.fn.system({ "hyprctl", "activewindow", "-j" })
  local main_addr = (pcall(vim.json.decode, main) and vim.json.decode(main).address) or nil

  S.job = vim.fn.jobstart({ "foot", "--app-id=dbout-results", "-o", "font-size-adjustment=" .. ZOOM_STEP,
    -- foot.ini's pad=14x14 plus the spare pixels foot leaves at the bottom made a
    -- gap under the status bar: keep the sides, trim top/bottom, split the spare.
    "-o", "pad=14x2 center", "nvim", "--listen", S.sock }, {
    detach = true,
    on_exit = function(id)
      vim.schedule(function()
        if S.job ~= id then
          return -- an older window, already closed (a new one may be open)
        end
        if S.job ~= nil or S.chan ~= nil then
          S.off = true -- closed from Hyprland (or failed): don't reopen by itself
        end
        reset()
      end)
    end,
  })
  if S.job <= 0 then
    vim.notify("Results window: could not start foot", vim.log.levels.ERROR)
    reset()
    return
  end

  -- Wait (without blocking) for the results nvim to listen, then size the
  -- split, hand focus back here, and show the current buffer's last result.
  local tries = 0
  local timer = vim.uv.new_timer()
  timer:start(100, 100, vim.schedule_wrap(function()
    tries = tries + 1
    if S.job == nil or tries > 100 then
      timer:stop()
      timer:close()
      return
    end
    if not vim.uv.fs_stat(S.sock) then
      return
    end
    timer:stop()
    timer:close()
    local ok, chan = pcall(vim.fn.sockconnect, "pipe", S.sock, { rpc = true })
    if not ok or chan == 0 then
      vim.notify("Results window: could not connect", vim.log.levels.ERROR)
      return
    end
    S.chan = chan
    if main_addr then
      place(main_addr)
    end
    -- Zoom out one step. Sent to the results window by address, so it never
    -- lands in whichever window has focus.
    local res = client("dbout-results")
    if res then
      hypr(string.format('hl.dsp.send_shortcut({ mods = "CTRL", key = "minus", window = "address:%s" })', res.address))
    end
    close_local_dbout()
    if not show(vim.api.nvim_get_current_buf(), true) then
      note("idle", IDLE_LINES)
    end
  end))
end

-- Hooks are set at file load, not in the spec's init: several kosetup files
-- spec vim-dadbod-ui, and lazy.nvim keeps only one init (dadbod-ui.lua's).
local group = vim.api.nvim_create_augroup("dadbod_results", { clear = true })

-- Pre fires while the query buffer is current, right after dadbod `pedit`s the
-- output buffer and BEFORE it starts the query job. Remember which query buffer
-- this output file belongs to (and its input file, for the caption's table
-- name). While the results window is open, also close that preview split here,
-- before the screen redraws, so it never flashes up. Safe at this point:
-- dadbod's buffer is bufhidden=delete and its BufUnload runs db#cancel, but
-- db#cancel only stops a job that already exists — and none does yet.
-- `canceled` is set first because dadbod's finish message otherwise appends
-- "(no window?)" when the output buffer has no window; nothing else reads it.
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "*DBExecutePre",
  callback = function(ev)
    local file = vim.fn.fnamemodify(ev.match, ":h")
    local obuf = vim.fn.bufnr(file)
    local input = obuf > 0 and vim.fn.getbufvar(obuf, "db_input") or ""
    input = type(input) == "string" and input or ""
    local qbuf = vim.api.nvim_get_current_buf()
    S.pending[file] = { qbuf = qbuf, input = input }
    -- "Running: <first line of the query>" until Post replaces it.
    local first = input ~= "" and vim.fn.filereadable(input) == 1 and vim.fn.readfile(input, "", 1)[1] or ""
    first = vim.trim(first or "")
    if first == "" then
      first = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(qbuf), ":t")
    end
    if vim.fn.strchars(first) > 80 then
      first = vim.fn.strcharpart(first, 0, 79) .. "…"
    end
    S.running[qbuf] = { text = first, started = os.time() }
    if not active() and not S.off then
      open() -- its connect step shows the running note
    elseif is_open() then
      show(qbuf, true)
    end
    if active() and obuf > 0 then
      S.pending[file].hidden = true
      -- extend() mutates dadbod's own query dict in place (vim.b would copy it)
      pcall(vim.cmd, string.format("call extend(getbufvar(%d, 'db', {}), {'canceled': 1})", obuf))
      for _, win in ipairs(vim.fn.win_findbuf(obuf)) do
        if #vim.api.nvim_list_wins() > 1 then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
    end
  end,
})

vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "*DBExecutePost",
  callback = function(ev)
    local file = vim.fn.fnamemodify(ev.match, ":h")
    local p = S.pending[file]
    S.pending[file] = nil
    local entry = { file = file, input = p and p.input or "" }
    if p then
      S.last[p.qbuf] = entry
      S.running[p.qbuf] = nil
    end
    if is_open() then
      -- Show it unless you've moved to another query tab meanwhile (that tab
      -- keeps its own result; switching back shows this one).
      local cur = vim.api.nvim_get_current_buf()
      if not p or cur == p.qbuf or not is_query_buf(cur) then
        push(entry, true)
      end
      vim.schedule(close_local_dbout) -- fallback if a split still slipped through
    elseif p and p.hidden and not active() then
      -- The window failed to start after the split was hidden: show it here.
      pcall(vim.cmd, "silent pedit " .. vim.fn.fnameescape(file))
    end
    -- Still starting up: open()'s connect step pushes the current buffer's last.
  end,
})

-- Switching query buffers shows that buffer's result (or running / no-results note).
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function(ev)
    if is_open() then
      show(ev.buf, false)
    end
  end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(ev)
    S.last[ev.buf] = nil
    S.running[ev.buf] = nil
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = close })

return {
  "kristijanhusak/vim-dadbod-ui",
  keys = {
    {
      "<leader>dw",
      function()
        if active() then
          S.off = true
          close()
        else
          S.off = false
          open()
        end
      end,
      desc = "Toggle results window",
    },
  },
}
