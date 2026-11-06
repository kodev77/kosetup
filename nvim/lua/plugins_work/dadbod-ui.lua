-- vim-dadbod-ui: database browser interface
return {
  "kristijanhusak/vim-dadbod-ui",
  dependencies = {
    { "tpope/vim-dadbod", lazy = true },
  },
  cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer", "DBUILastQueryInfo" },
  init = function()
    vim.g.db_ui_use_nerd_fonts = 1
    vim.g.db_ui_show_database_icon = 1
    vim.g.db_ui_win_position = "left"
    vim.g.db_ui_winwidth = 40
    vim.g.db_ui_save_location = vim.fn.expand("~/.local/share/db_ui")
    vim.g.db_ui_execute_on_save = 0
    -- Send "Done after…" etc. through vim.notify (LazyVim's themed notifier).
    -- DBUI's own pop-up takes Normal's bg, and on a transparent Omarchy theme
    -- that's empty, so it paints a cream box with white text.
    vim.g.db_ui_use_nvim_notify = 1
    -- Postgres through autoload/db/adapter/kopsql.vim: the stock adapter with
    -- psql's column padding squashed (a huge HTML/JSON value padded every row
    -- to ~800K chars). "postgres:" URLs alias to postgresql in dadbod.
    -- Only when kopsql.vim is linked: a machine that git-pulls this file before
    -- re-running install.sh keeps the stock adapter instead of "no adapter".
    if #vim.api.nvim_get_runtime_file("autoload/db/adapter/kopsql.vim", false) > 0 then
      vim.g.db_adapter_postgresql = "db#adapter#kopsql#"
      vim.g.db_adapter_postgres = "db#adapter#kopsql#"
    end

    -- Load table helpers from util/dadbod-tables/ (added by db adapter migrations)
    local helpers = {}
    local tables_dir = vim.fn.stdpath("config") .. "/lua/util/dadbod-tables"
    if vim.fn.isdirectory(tables_dir) == 1 then
      for _, file in ipairs(vim.fn.glob(tables_dir .. "/*.lua", false, true)) do
        local name = vim.fn.fnamemodify(file, ":t:r")
        local ok, tbl = pcall(dofile, file)
        if ok and tbl then
          helpers[name] = tbl
        end
      end
    end
    vim.g.db_ui_table_helpers = helpers
  end,
}
