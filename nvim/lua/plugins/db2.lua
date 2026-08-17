-- db2 - a neovim password manager
-- Converted from VimScript: repo/dotfiles/stow/vim-db2/.vim/plugin/db2.vim

return {
  {
    dir = vim.fn.stdpath("config"),
    name = "db2",
    keys = {
      {
        "<leader>d2",
        function()
          require("util.db2").open()
        end,
        desc = "Open Db2",
      },
    },
    cmd = "Db2",
    config = function()
      vim.api.nvim_create_user_command("Db2", function(opts)
        require("util.db2").open(opts.args)
      end, { nargs = "?", complete = "file" })
    end,
  },
}
