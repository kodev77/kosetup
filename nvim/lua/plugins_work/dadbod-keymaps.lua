-- Dadbod keybindings for DBUI, query execution, and connection management.
-- NOTE (devuan port): the whole DB group lives under <leader>d (this box uses
-- DB tools constantly, debug rarely, so dadbod owns <leader>d and dap is on
-- <leader>D). Query-exec is <leader>dr (run line / visual selection) and
-- <leader>dR (run file) instead of komarchy's <leader>r/<leader>R, because
-- <leader>r is bound globally to Telescope oldfiles (Recent files) here.
return {
  "kristijanhusak/vim-dadbod-ui",
  keys = {
    {
      "<leader>db",
      function()
        -- Close neo-tree if open
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "neo-tree" then
            vim.api.nvim_win_close(win, true)
          end
        end
        -- Replace dashboard with empty buffer
        local ft = vim.bo.filetype
        if ft == "snacks_dashboard" or ft == "alpha" or ft == "starter" or ft == "dashboard" then
          vim.cmd("enew")
        end
        vim.cmd("DBUIToggle")
      end,
      desc = "Toggle DBUI",
    },
    { "<leader>df", "<cmd>DBUIFindBuffer<CR>", desc = "Find DB buffer" },
    { "<leader>dl", "<cmd>DBUILastQueryInfo<CR>", desc = "Last query info" },
    {
      "<leader>ds",
      function()
        require("util.dadbod-helpers").select_connection()
      end,
      desc = "Select DB connection",
    },
    {
      "<leader>dc",
      function()
        require("util.dadbod-helpers").show_connection()
      end,
      desc = "Show DB connection",
    },
    {
      "<leader>dF",
      function()
        require("util.dadbod-format").format_from_anywhere()
      end,
      desc = "Format DB output",
    },
    {
      "<leader>dd",
      function()
        local h = require("util.dadbod-helpers")
        h.execute_query(h.get_query_under_cursor())
      end,
      ft = { "sql", "mysql", "plsql" },
      desc = "Execute query under cursor",
    },
    {
      "<leader>dd",
      function()
        local h = require("util.dadbod-helpers")
        h.execute_query(h.get_visual_selection())
      end,
      mode = "v",
      ft = { "sql", "mysql", "plsql" },
      desc = "Execute selection",
    },
    {
      "<leader>dr",
      function()
        require("util.dadbod-helpers").execute_query(vim.api.nvim_get_current_line())
      end,
      ft = { "sql", "mysql", "plsql" },
      desc = "Execute current line",
    },
    {
      "<leader>dr",
      function()
        require("util.dadbod-helpers").execute_query(require("util.dadbod-helpers").get_visual_selection())
      end,
      mode = "v",
      ft = { "sql", "mysql", "plsql" },
      desc = "Execute selection",
    },
    {
      "<leader>dR",
      function()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        require("util.dadbod-helpers").execute_query(table.concat(lines, "\n"))
      end,
      ft = { "sql", "mysql", "plsql" },
      desc = "Execute entire file",
    },
    {
      "<leader>cp",
      function()
        require("util.dadbod-helpers").copy_popup_content()
      end,
      desc = "Copy popup content",
    },
  },
}
