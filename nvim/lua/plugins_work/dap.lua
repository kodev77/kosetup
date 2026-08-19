-- C# / .NET debugging stack (DAP).
--
-- Ported from komarchy group 012 (012-00049-dot-dap.sh + the dap pieces of
-- 012-00050-dot-syn.sh). komarchy targets the LazyVim distro, where the
-- `lang.dotnet` extra already provides nvim-dap + the netcoredbg adapter, so
-- its script only APPENDS a launch config. This config is hand-rolled
-- lazy.nvim (not LazyVim), so we provide the whole stack here:
--   * nvim-dap          — the debug engine
--   * nvim-dap-ui       — scopes/breakpoints/stacks/watches/repl panels
--   * dap-virtual-text  — inline variable values next to code
--   * mason-nvim-dap    — installs the `netcoredbg` adapter binary via mason
-- omnisharp (LSP) and the c_sharp treesitter parser are already handled in
-- plugins/lsp.lua and plugins/treesitter.lua respectively.
--
-- Keymaps mirror LazyVim's dap.core defaults but under <leader>D* (not the
-- LazyVim <leader>d*): on this box <leader>d is the database/dadbod group,
-- which gets used constantly, while debug is rare — so they're swapped.
-- Diagnostics live under <leader>cd (plugins/lsp.lua).

-- LazyVim's get_args helper: prompt for launch args on <leader>Da.
local function get_args(config)
  local args = type(config.args) == "function" and (config.args() or {}) or config.args or {}
  config = vim.deepcopy(config)
  config.args = function()
    local new_args = vim.fn.input("Run with args: ", table.concat(args, " "))
    return vim.split(vim.fn.trim(new_args), " ")
  end
  return config
end

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
      "theHamsta/nvim-dap-virtual-text",
      {
        -- mason bridge: ensures the netcoredbg binary is installed. We define
        -- the adapter ourselves below, so handlers are left empty to avoid
        -- mason-nvim-dap registering a second (coreclr) adapter + configs.
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { "mason-org/mason.nvim" },
        opts = {
          -- Keyed by the nvim-dap ADAPTER name, not the mason package name:
          -- mason-nvim-dap resolves it through mappings.source.nvim_dap_to_package,
          -- where ['coreclr'] = 'netcoredbg'. Passing "netcoredbg" here misses the
          -- lookup, and because it goes through Optional:if_present() it no-ops
          -- SILENTLY — no error, no notify, the adapter binary just never installs.
          ensure_installed = { "coreclr" },
          automatic_installation = true,
          handlers = {},
        },
      },
    },
    -- LazyVim dap.core defaults, but relocated to the <leader>D prefix
    -- (database/dadbod owns <leader>d here). Diagnostics: <leader>cd (lsp.lua).
    keys = {
      { "<leader>DB", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Breakpoint Condition" },
      { "<leader>Dd", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>Dc", function() require("dap").continue() end, desc = "Run/Continue" },
      { "<leader>Da", function() require("dap").continue({ before = get_args }) end, desc = "Run with Args" },
      { "<leader>DC", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
      { "<leader>Dg", function() require("dap").goto_() end, desc = "Go to Line (No Execute)" },
      { "<leader>Di", function() require("dap").step_into() end, desc = "Step Into" },
      { "<leader>Dj", function() require("dap").down() end, desc = "Down" },
      { "<leader>Dk", function() require("dap").up() end, desc = "Up" },
      { "<leader>Dl", function() require("dap").run_last() end, desc = "Run Last" },
      { "<leader>Do", function() require("dap").step_out() end, desc = "Step Out" },
      { "<leader>DO", function() require("dap").step_over() end, desc = "Step Over" },
      { "<leader>DP", function() require("dap").pause() end, desc = "Pause" },
      { "<leader>Dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>Ds", function() require("dap").session() end, desc = "Session" },
      { "<leader>Dt", function() require("dap").terminate() end, desc = "Terminate" },
      { "<leader>Dw", function() require("dap.ui.widgets").hover() end, desc = "Widgets" },
      { "<leader>Du", function() require("dapui").toggle({}) end, desc = "Dap UI" },
      { "<leader>De", function() require("dapui").eval() end, desc = "Eval", mode = { "n", "v" } },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()
      require("nvim-dap-virtual-text").setup()

      -- Open/close the UI automatically with the debug session.
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

      -- Gutter signs (reuse diagnostic highlight groups so they pick up the
      -- active colorscheme).
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError", linehl = "", numhl = "" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn", linehl = "", numhl = "" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual", numhl = "" })

      -- netcoredbg adapter. Point at the mason install path directly so it
      -- resolves even before mason adds its bin dir to PATH on a fresh start.
      dap.adapters.netcoredbg = {
        type = "executable",
        command = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg",
        args = { "--interpreter=vscode" },
      }

      dap.configurations.cs = dap.configurations.cs or {}

      -- Generic: prompt for any built dll.
      table.insert(dap.configurations.cs, {
        type = "netcoredbg",
        name = "Launch (pick dll)",
        request = "launch",
        program = function()
          return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
        end,
        cwd = "${workspaceFolder}",
        console = "internalConsole",
      })

      -- Project-specific: JobTracker DataverseIntegration tests
      -- (ported verbatim from komarchy 012-00049-dot-dap.sh).
      table.insert(dap.configurations.cs, {
        type = "netcoredbg",
        name = "JobTracker.Tests.DataverseIntegration",
        request = "launch",
        program = "${workspaceFolder}/JobTracker.Tests.DataverseIntegration/bin/Debug/net10.0/JobTracker.Tests.DataverseIntegration.dll",
        cwd = "${workspaceFolder}/JobTracker.Tests.DataverseIntegration",
        console = "internalConsole",
        stopAtEntry = true,
      })
    end,
  },
}
