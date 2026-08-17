-- Work-only language servers, LazyVim-convention additive opts.servers.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        omnisharp = {}, -- C#
        ts_ls = {},     -- TypeScript / JavaScript
        -- Angular Language Service: template type-checking + completion (ts_ls
        -- covers the .ts logic). ngserver, its bundled TypeScript, and the
        -- @angular/language-service it loads are all shipped by Mason, so the
        -- project needs no extra deps. NOTE the two probe paths differ: the
        -- language-SERVICE lives one level deeper, nested inside the
        -- language-SERVER's own node_modules — pointing ngProbe at the top
        -- level fails to resolve the service and the client exits 1.
        angularls = {
          cmd = (function()
            local pkg = vim.fn.stdpath("data") .. "/mason/packages/angular-language-server"
            return {
              "ngserver", "--stdio",
              "--tsProbeLocations", pkg .. "/node_modules",
              "--ngProbeLocations", pkg .. "/node_modules/@angular/language-server/node_modules",
            }
          end)(),
          filetypes = { "typescript", "html", "htmlangular" },
          root_markers = { "angular.json", "nx.json", "project.json" },
        },
      },
    },
  },
}
