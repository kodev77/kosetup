-- Query result row count on the status line, after the file name: "200 rows", or
-- "3 tables · 250 rows" when a query returns several. dadbod-format sets the
-- counts only when a table was shown, so DELETE/UPDATE/... add nothing here
-- (their message stays in the result itself).
local function counts()
  local buf = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
  if vim.bo[buf].filetype ~= "dbout" then
    return nil
  end
  return vim.b[buf].dbout_row_count, vim.b[buf].dbout_table_count
end

return {
  "nvim-lualine/lualine.nvim",
  optional = true,
  opts = function(_, opts)
    opts.sections = opts.sections or {}
    opts.sections.lualine_c = opts.sections.lualine_c or {}
    table.insert(opts.sections.lualine_c, {
      function()
        local rows, tables = counts()
        local text = rows .. (rows == 1 and " row" or " rows")
        if tables and tables > 1 then
          text = tables .. " tables · " .. text
        end
        return text
      end,
      cond = function()
        return counts() ~= nil
      end,
    })
  end,
}
