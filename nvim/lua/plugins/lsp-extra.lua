-- Extra language servers layered onto the host config's LSP setup (omarchy/LazyVim
-- convention: entries in opts.servers are merged additively and auto-installed via
-- mason). Work-only servers (omnisharp/ts_ls/angularls) live in lsp-work.lua.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},
        pyright = {},
        jsonls = {},
        yamlls = {},
      },
    },
  },
}
