-- Blink.cmp integration: register vim-dadbod-completion as a source provider
-- for SQL filetypes so autocomplete suggests table/column names
return {
  "saghen/blink.cmp",
  optional = true,
  opts = {
    sources = {
      per_filetype = {
        sql = { inherit_defaults = true, "dadbod" },
        mysql = { inherit_defaults = true, "dadbod" },
        plsql = { inherit_defaults = true, "dadbod" },
      },
      providers = {
        dadbod = {
          name = "Dadbod",
          module = "vim_dadbod_completion.blink",
        },
      },
    },
  },
}
