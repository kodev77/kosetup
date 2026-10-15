-- LSP-free code navigation. Everything here runs on tools LazyVim already
-- ships (snacks picker, ripgrep, tree-sitter) — no server process, no memory.
--
--   <leader>ss   symbols in the current file via tree-sitter (functions,
--                classes, methods...). LazyVim's default binds this to the LSP
--                document-symbol picker, which only exists while a server is
--                attached. This one always works. If an LSP later attaches to
--                the buffer, LazyVim's buffer-local LSP binding takes over for
--                that buffer — same key, richer results.
--
-- For reference, the ripgrep-backed keys LazyVim already provides:
--   <leader>/  or <leader>sg   live grep the project
--   <leader>sw                 grep word under cursor (poor man's go-to-def)
--   <leader><space> / ff       find file by name
--   Ctrl-q inside a picker     dump results to quickfix; walk with ]q [q
return {
  {
    "folke/snacks.nvim",
    -- Bigfile guard: LazyVim marks any file whose AVERAGE line is > 1000 chars
    -- as ft=bigfile and strips LSP + tree-sitter from it, meaning no <leader>cf
    -- ("No formatter available"). That catches every one-line JSON config, e.g.
    -- a 1.1 KB odp-telemetry-units file in JobTracker. Raise the bar so small
    -- single-line files keep the full treatment; real minified bundles (hundreds
    -- of thousands of chars per line) still trip it. Size cap (1.5 MB) unchanged.
    opts = { bigfile = { line_length = 20000 } },
    keys = {
      {
        "<leader>ss",
        function()
          Snacks.picker.treesitter({ filter = LazyVim.config.kind_filter })
        end,
        desc = "Symbols (tree-sitter)",
      },
    },
  },
}
