-- vim-dadbod-completion: SQL completion source for dadbod
return {
  "kristijanhusak/vim-dadbod-ui",
  dependencies = {
    { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
  },
}
