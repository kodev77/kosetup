-- Make the neo-tree root and nvim's working directory move together.
--
-- LazyVim deliberately unties them (filesystem.bind_to_cwd = false), so the
-- stock "." only zooms the tree. Here "." and <BS> keep their tree behaviour
-- and ALSO :cd to the same folder, so afterwards the cwd-scoped pickers
-- (<leader>sG grep, <leader>fF files, <leader>sW word) search just that
-- subtree. The root-scoped lowercase keys are unaffected.
--
--   .     tree root -> folder under cursor (or the file's folder), and :cd there
--   <BS>  tree root -> parent folder, and :cd there
local function cd(dir)
  if dir and dir ~= "" and dir ~= vim.uv.cwd() then
    vim.cmd.cd(vim.fn.fnameescape(dir))
    vim.notify("cwd: " .. vim.fn.fnamemodify(dir, ":~"), vim.log.levels.INFO, { title = "neo-tree" })
  end
end

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        window = {
          mappings = {
            ["."] = {
              function(state)
                local node = state.tree:get_node()
                while node and node.type ~= "directory" do
                  local pid = node:get_parent_id()
                  node = pid and state.tree:get_node(pid) or nil
                end
                require("neo-tree.sources.filesystem.commands").set_root(state)
                if node then
                  cd(node.path)
                end
              end,
              desc = "Set root + cd",
            },
            ["<bs>"] = {
              function(state)
                local old = state.path
                local parent = vim.fn.fnamemodify(old, ":h")
                require("neo-tree.sources.filesystem.commands").navigate_up(state)
                if parent ~= old then -- already at filesystem root: nothing to do
                  cd(parent)
                end
              end,
              desc = "Navigate up + cd",
            },
          },
        },
      },
    },
  },
}
