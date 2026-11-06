-- Dadbod autocmds: DBUI behavior, dbout auto-formatting, highlights, and DBSelect command
return {
  "kristijanhusak/vim-dadbod-ui",
  config = function()
    -- Dbout highlight groups — ANSI-only.
    -- These set ONLY ctermfg (ANSI slots 0-15), no gui hex, so the colours
    -- ride whatever xfce4-terminal palette is active and never use truecolor.
    -- Linking to standard groups (String/Type/...) does NOT work here: nvim's
    -- default colorscheme leaves most of them without a cterm value, so in
    -- ride mode they silently fall back to the normal fg.
    --
    -- All data values are blue (slot 12); NULLs, borders, header names and the
    -- row-count caption are dim (slot 8). No green/default-fg colours remain.
    --
    -- With termguicolors on (LazyVim, Omarchy) ctermfg is ignored and all of
    -- the above showed as the bright normal text. So each group also gets a
    -- gui colour taken from the current theme: data is the normal text colour
    -- softened 75% of the way from the background, the dim groups use the
    -- theme's Comment colour. Omarchy themes are transparent (Normal has no
    -- bg), so the blend falls back to black/white by 'background'.
    local function theme_colors()
      local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
      local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
      local fg = normal.fg or (vim.o.background == "light" and 0x000000 or 0xffffff)
      local bg = normal.bg or (vim.o.background == "light" and 0xffffff or 0x000000)
      local function mix(a, b, t) -- t of a, the rest of b, per channel
        local out = 0
        for shift = 16, 0, -8 do
          local ca, cb = bit.band(bit.rshift(a, shift), 0xff), bit.band(bit.rshift(b, shift), 0xff)
          out = out + bit.lshift(math.floor(ca * t + cb * (1 - t) + 0.5), shift)
        end
        return string.format("#%06x", out)
      end
      local data = mix(fg, bg, 0.75)
      local dim = comment.fg and string.format("#%06x", comment.fg) or mix(fg, bg, 0.5)
      return data, dim
    end

    local function set_dbout_highlights()
      local data, dim = theme_colors()
      vim.api.nvim_set_hl(0, "DboutString", { ctermfg = 12, fg = data })    -- blue
      vim.api.nvim_set_hl(0, "DboutGuid", { ctermfg = 12, fg = data })      -- blue
      vim.api.nvim_set_hl(0, "DboutTimestamp", { ctermfg = 12, fg = data }) -- blue (date/datetime)
      vim.api.nvim_set_hl(0, "DboutNumber", { ctermfg = 12, fg = data })    -- blue
      vim.api.nvim_set_hl(0, "DboutTruncated", { ctermfg = 12, fg = data }) -- blue (truncated data)
      vim.api.nvim_set_hl(0, "DboutNull", { ctermfg = 8, fg = dim, italic = true }) -- dim + italic
      vim.api.nvim_set_hl(0, "DboutBorder", { ctermfg = 8, fg = dim })     -- dim
      vim.api.nvim_set_hl(0, "DboutHeader", { ctermfg = 8, fg = dim, bold = true }) -- dim + bold
      vim.api.nvim_set_hl(0, "DboutRowCount", { ctermfg = 8, fg = dim, italic = true }) -- dim italic caption
      vim.api.nvim_set_hl(0, "DboutError", { ctermfg = 8, fg = dim }) -- dim error messages
    end
    set_dbout_highlights()
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = set_dbout_highlights,
    })

    -- User command for connection selection
    vim.api.nvim_create_user_command("DBSelect", function()
      require("util.dadbod-helpers").select_connection()
    end, {})

    -- The DBUI drawer connects without going through the picker — refresh the
    -- Azure PG token whenever it opens so azure_dev_pg never password-prompts.
    vim.api.nvim_create_autocmd("User", {
      pattern = "DBUIOpened",
      callback = function()
        require("util.dadbod-helpers").azure_pg_token()
      end,
    })

    local group = vim.api.nvim_create_augroup("dadbod_config", { clear = true })

    -- DBUI: map o to select line
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "dbui",
      callback = function()
        vim.bo.modifiable = true
        vim.keymap.set("n", "o", "<Plug>(DBUI_SelectLine)", { buffer = true })
      end,
    })

    -- dbout: auto-format and keybindings
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "dbout",
      callback = function()
        local fmt = require("util.dadbod-format")
        vim.bo.modifiable = true
        vim.wo.foldenable = false
        -- No snacks indent guides: a "^" error marker or indented line would get a │
        vim.b.snacks_indent = false
        fmt.auto_format()
        fmt.setup_frozen_headers(vim.api.nvim_get_current_buf())
        vim.keymap.set("n", "<CR>", fmt.expand_cell, { buffer = true, desc = "Expand cell" })
        -- dbout view-toggles live under the "database" (<leader>d) group so
        -- which-key surfaces them there, not under the global "Find files" (f).
        vim.keymap.set("n", "<leader>dT", fmt.toggle_raw, { buffer = true, desc = "Toggle raw/formatted output" })
        vim.keymap.set("n", "<leader>dt", fmt.toggle_truncate, { buffer = true, desc = "Toggle truncation (full/short)" })
        vim.keymap.set("n", "q", fmt.close_expand, { buffer = true, desc = "Close expand" })
      end,
    })

    -- dbout: format on BufEnter if not yet formatted
    vim.api.nvim_create_autocmd("BufEnter", {
      group = group,
      callback = function()
        if vim.bo.filetype == "dbout" and vim.b.dbout_is_formatted ~= 1 then
          require("util.dadbod-format").format()
        end
      end,
    })

    -- After any query finishes, a 0-row result writes no output and leaves the
    -- dbout window blank — show "(0 rows affected)" instead.
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "*DBExecutePost",
      callback = function()
        vim.schedule(function()
          require("util.dadbod-format").finalize_empty()
        end)
      end,
    })
  end,
}
