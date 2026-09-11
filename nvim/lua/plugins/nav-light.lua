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
