-- Dadbod helper utilities: query execution, connection management, and clipboard
local M = {}

--- Remove SQL comments (`-- ` to end-of-line and multi-line `/* */`) from a
--- string. Used to find the statement verb and count statements without being
--- fooled by commented-out `;` or keywords. (String literals aren't tracked —
--- a `--`/`/*` inside a quoted string is a rare false positive.)
local function strip_sql_comments(s)
  local out, i, n, block = {}, 1, #s, false
  while i <= n do
    if block then
      local close = s:find("*/", i, true)
      if close then
        i = close + 2
        block = false
      else
        i = n + 1
      end
    else
      local two = s:sub(i, i + 1)
      if two == "/*" then
        block = true
        i = i + 2
      elseif two == "--" then
        local nl = s:find("\n", i, true)
        i = nl or (n + 1)
      else
        out[#out + 1] = s:sub(i, i)
        i = i + 1
      end
    end
  end
  return table.concat(out)
end

--- Execute a SQL query via vim-dadbod
--- For a lone MySQL/MariaDB modifying statement, appends ROW_COUNT() to show
--- affected rows.
function M.execute_query(query)
  query = vim.trim(query)
  if query == "" then
    return
  end

  local db = vim.b.db or vim.g.db or ""
  local is_mysql = db:lower():match("^mysql:")

  -- Verb + single-statement detection on the comment-stripped code (so a
  -- leading comment doesn't hide the verb, and a `;` inside a comment doesn't
  -- look like a second statement).
  local body = vim.trim(strip_sql_comments(query)):gsub("%s*;%s*$", "")
  local verb = (body:match("^(%a+)") or ""):lower()
  local is_modify = verb == "insert" or verb == "update" or verb == "delete"
  local single_stmt = not body:find(";", 1, true)

  -- Append ROW_COUNT() only for a LONE modifying statement. For a multi-
  -- statement batch (e.g. INSERT; SELECT) ROW_COUNT would reflect the trailing
  -- statement — after a SELECT it returns -1 ("(-1 rows affected)").
  if is_mysql and is_modify and single_stmt then
    query = query:gsub("%s*;%s*$", "")
    query = query .. "; SELECT ROW_COUNT() as rows_affected;"
  end

  -- Write to a temp file, one buffer line per file line, so embedded newlines
  -- and `--` line comments survive. (Collapsing to a single line would let a
  -- leading comment swallow the whole statement.)
  local tmpfile = vim.fn.tempname() .. ".sql"
  vim.fn.writefile(vim.split(query, "\n", { plain = true }), tmpfile)
  vim.cmd("DB < " .. vim.fn.fnameescape(tmpfile))
end

--- Strip SQL comments for boundary analysis. Returns two parallel arrays:
---   code[i]     = line i with `--` and (possibly multi-line) `/* */` comments removed
---   in_block[i] = true if line i begins inside an open `/* */` block comment
--- (String literals are not tracked, so a `--`/`/*` inside a quoted string is a
--- rare false positive — acceptable for boundary detection.)
local function analyze_comments(lines)
  local code, in_block = {}, {}
  local block = false
  for i, line in ipairs(lines) do
    in_block[i] = block
    local res, j, n = {}, 1, #line
    while j <= n do
      if block then
        local close = line:find("*/", j, true)
        if close then
          j = close + 2
          block = false
        else
          j = n + 1 -- rest of line is inside the block comment
        end
      else
        local two = line:sub(j, j + 1)
        if two == "/*" then
          block = true
          j = j + 2
        elseif two == "--" then
          break -- line comment: ignore the rest of the line
        else
          res[#res + 1] = line:sub(j, j)
          j = j + 1
        end
      end
    end
    code[i] = table.concat(res)
  end
  return code, in_block
end

--- Return the SQL statement the cursor is in, as a single string.
--- A statement is bounded by a blank line OR a `;`-terminated line (whichever is
--- nearer), computed on the comment-stripped text so `-- ` and `/* */` comments
--- (trailing, inline, internal, or multi-line) don't fool the boundaries.
--- Comments are kept in the returned text (the backend ignores them). Returns ""
--- if the cursor is on a blank line outside any statement.
function M.get_query_under_cursor()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local code, in_block = analyze_comments(lines)

  -- A boundary blank is a truly empty line that is NOT inside a block comment
  -- (so a blank line within /* */ never splits a statement).
  local function boundary_blank(i)
    return i < 1 or i > #lines or (vim.trim(lines[i]) == "" and not in_block[i])
  end
  -- A statement ends where the comment-stripped code ends with `;`.
  local function ends_stmt(i)
    return i >= 1 and i <= #lines and vim.trim(code[i]):match(";%s*$") ~= nil
  end

  if boundary_blank(cur) then
    return ""
  end

  -- Scan up: stop when the line above is a boundary blank or ends the prior statement.
  local first = cur
  while first > 1 and not boundary_blank(first - 1) and not ends_stmt(first - 1) do
    first = first - 1
  end

  -- Scan down: stop at the first `;`-terminated line (inclusive) or before a blank.
  local last = cur
  while last < #lines and not ends_stmt(last) and not boundary_blank(last + 1) do
    last = last + 1
  end

  return table.concat(vim.list_slice(lines, first, last), "\n")
end

--- Get text from the visual selection.
--- When called from within a visual-mode mapping the '< '> marks are still
--- stale (they only update on leaving visual mode), so read the LIVE selection
--- endpoints — 'v' (other end) and '.' (cursor) — and let getregion() handle
--- charwise/linewise/blockwise. Falls back to the marks if invoked elsewhere.
function M.get_visual_selection()
  local mode = vim.fn.mode()
  local p1, p2
  if mode == "v" or mode == "V" or mode == "\22" then
    p1, p2 = vim.fn.getpos("v"), vim.fn.getpos(".")
  else
    mode = vim.fn.visualmode()
    p1, p2 = vim.fn.getpos("'<"), vim.fn.getpos("'>")
  end
  local ok, region = pcall(vim.fn.getregion, p1, p2, { type = mode == "" and "v" or mode })
  if not ok then
    return ""
  end
  return table.concat(region, "\n")
end

--- Copy floating window content to clipboard
function M.copy_popup_content()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative and config.relative ~= "" then
      local buf = vim.api.nvim_win_get_buf(win)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      if #lines > 0 then
        vim.fn.setreg("+", table.concat(lines, "\n"))
        vim.notify("Copied " .. #lines .. " lines to clipboard")
        return
      end
    end
  end
  vim.notify("No popups visible")
end

--- Read and validate the saved connections list from connections.json.
--- Returns a list of { name, url } tables, or nil + a notify on any problem.
local function load_connections()
  local save_loc = vim.g.db_ui_save_location or vim.fn.expand("~/.local/share/db_ui")
  local conn_file = save_loc .. "/connections.json"

  if vim.fn.filereadable(conn_file) == 0 then
    vim.notify("No saved connections found at " .. conn_file)
    return nil
  end

  local json_str = table.concat(vim.fn.readfile(conn_file), "")
  local ok, connections = pcall(vim.json.decode, json_str)
  if not ok or not connections or #connections == 0 then
    vim.notify("No connections configured")
    return nil
  end

  local entries = {}
  for _, conn in ipairs(connections) do
    local name = conn.name or ""
    local url = conn.url or ""
    if name ~= "" and url ~= "" then
      entries[#entries + 1] = { name = name, url = url }
    end
  end

  if #entries == 0 then
    vim.notify("No connections configured")
    return nil
  end

  return entries
end

--- For Azure postgres URLs without an embedded password, psql needs the Entra
--- token as its password — fetch one via az and export it as PGPASSWORD.
local last_pg_token_time = 0

local function ensure_azure_pg_token(url)
  if not url:match("postgres%.database%.azure%.com") then
    return
  end
  if url:match("://[^:@/]+:[^@/]+@") then
    return -- URL carries its own password
  end
  if os.time() - last_pg_token_time < 3000 then
    return -- current token still has life left
  end
  local token = vim.fn.system({ "az", "account", "get-access-token", "--resource-type", "oss-rdbms", "--query", "accessToken", "-o", "tsv" })
  if vim.v.shell_error ~= 0 then
    vim.notify("az token fetch failed (run az login?): " .. vim.trim(token), vim.log.levels.ERROR)
    return
  end
  vim.env.PGPASSWORD = vim.trim(token)
  last_pg_token_time = os.time()
  vim.notify("Azure PG token set (valid ~1h)")
end

--- Manual refresh for DBUI-drawer sessions that bypass the picker.
function M.azure_pg_token()
  ensure_azure_pg_token("postgres.database.azure.com")
end

--- Select a database connection using a Telescope picker
--- (komarchy used Snacks.picker; this box runs Telescope instead)
function M.select_connection()
  local entries = load_connections()
  if not entries then
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = "Select DB Connection",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(e)
          return { value = e, display = e.name, ordinal = e.name }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            local e = selection.value
            ensure_azure_pg_token(e.url)
            vim.b.db = e.url
            vim.b.db_name = e.name
            vim.notify("Connected to: " .. e.name)
          end
        end)
        return true
      end,
    })
    :find()
end

--- Show current database connection
function M.show_connection()
  local name = vim.b.db_name or ""
  local url = vim.b.db or vim.g.db or ""
  if name == "" then
    local db_ok, statusline = pcall(vim.fn["db_ui#statusline"], { prefix = "", show = { "db_name" } })
    if db_ok then
      name = statusline
    end
  end
  if name ~= "" and url ~= "" then
    vim.notify("DB: " .. name .. "  " .. url)
  elseif url ~= "" then
    vim.notify("DB: " .. url)
  else
    vim.notify("No database connection")
  end
end

return M
