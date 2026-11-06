-- Show trailing spaces as plain spaces. LazyVim turns on `list`, and nvim's
-- default listchars draws every trailing space as `-` — so while typing, each
-- space you just entered shows as a dash. Drop only the `trail` marker; tabs
-- (`>`) and non-breaking spaces (`+`) stay visible since those are invisible
-- otherwise and easy to paste in by accident. Nothing else sets listchars, so
-- setting it here (at spec load) needs no ordering against LazyVim's options.
vim.opt.listchars = { tab = "> ", nbsp = "+" }

return {}
