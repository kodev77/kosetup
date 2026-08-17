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
    local function set_dbout_highlights()
      vim.api.nvim_set_hl(0, "DboutString", { ctermfg = 12 })    -- blue
      vim.api.nvim_set_hl(0, "DboutGuid", { ctermfg = 12 })      -- blue
      vim.api.nvim_set_hl(0, "DboutTimestamp", { ctermfg = 12 }) -- blue (date/datetime)
      vim.api.nvim_set_hl(0, "DboutNumber", { ctermfg = 12 })    -- blue
      vim.api.nvim_set_hl(0, "DboutTruncated", { ctermfg = 12 }) -- blue (truncated data)
      vim.api.nvim_set_hl(0, "DboutNull", { ctermfg = 8, italic = true }) -- dim + italic
      vim.api.nvim_set_hl(0, "DboutBorder", { ctermfg = 8 })     -- dim
      vim.api.nvim_set_hl(0, "DboutHeader", { ctermfg = 8, bold = true }) -- dim + bold
      vim.api.nvim_set_hl(0, "DboutRowCount", { ctermfg = 8, italic = true }) -- dim italic caption
      vim.api.nvim_set_hl(0, "DboutError", { ctermfg = 8 }) -- dim error messages
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
