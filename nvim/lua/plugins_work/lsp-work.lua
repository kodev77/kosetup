-- Work-only language servers, LazyVim-convention additive opts.servers.
--
-- These three are ON-DEMAND: Mason still installs them, but they do not start
-- when a .cs/.ts/.html buffer opens. Together they idle at ~1-3 GB (OmniSharp
-- alone ~1.8 GB) and day-to-day navigation runs on ripgrep + tree-sitter
-- (see plugins/nav-light.lua). Press <leader>cL to bring them up for the
-- current session when a real go-to-definition / find-references is needed.
--
-- Mechanism: LazyVim's opts.setup[server] hook. Returning true means "I handled
-- it" — LazyVim then skips vim.lsp.enable() and excludes the server from
-- mason-lspconfig's automatic_enable, while still adding it to ensure_installed.
-- (The old `autostart = false` flag is ignored by the vim.lsp.enable() path.)
local ON_DEMAND = { "omnisharp", "ts_ls", "angularls" }

local function configure_only(server, sopts)
  vim.lsp.config(server, sopts)
  return true
end

return {
  -- Tree-sitter parser for C#. Not in LazyVim's default set, and the LSP-free
  -- <leader>ss symbols picker (plugins/nav-light.lua) has nothing to walk
  -- without it. LazyVim auto-installs anything listed here on startup.
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "c_sharp" } } },
  {
    "neovim/nvim-lspconfig",
    keys = {
      {
        "<leader>cL",
        function()
          vim.lsp.enable(ON_DEMAND)
          vim.notify("LSP started: " .. table.concat(ON_DEMAND, ", "), vim.log.levels.INFO, { title = "kosetup" })
        end,
        desc = "Start work LSP (omnisharp/ts_ls/angularls)",
      },
    },
    opts = {
      setup = {
        omnisharp = configure_only,
        ts_ls = configure_only,
        angularls = configure_only,
      },
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
