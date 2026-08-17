-- Buffer-local setup for DASM / 6502 assembly (.asm):
--   * Merlin-style column tabbing (label · opcode · operand · comment)
--   * `gf` / <C-w>f opens include files like "vcs.h" / "macro.h"
--   * ';' comments, and free-form indent (no autoindent fighting column layout)
-- Go-to-definition on symbols (<C-]>) is provided by ctags + vim-gutentags.

-- --- comments --------------------------------------------------------------
vim.bo.commentstring = "; %s"
vim.bo.comments = ":;"

-- --- indentation -------------------------------------------------------------
-- Plain autoindent keeps the column layout flowing: Enter after code indented
-- to the opcode column continues at that column; Enter after a col-0 label
-- stays at col 0. smartindent stays off (it fights hand-laid columns).
vim.bo.expandtab = true
vim.bo.shiftwidth = 8
vim.bo.tabstop = 8
vim.bo.softtabstop = 8
vim.bo.autoindent = true
vim.opt_local.smartindent = false

-- --- Merlin-style column tab ----------------------------------------------
-- <Tab> jumps to the next fixed column, padding with spaces:
--   col 1        col 9      col 17      col 33
--   LABEL        LDA        #$0E        ; comment
-- Adjust these column numbers (1-based) to taste.
local COLUMNS = { 9, 17, 33 }
vim.keymap.set("i", "<Tab>", function()
  -- this buffer-local map shadows blink.cmp's global <Tab>: when the
  -- completion menu is open, accept instead of column-tabbing
  local ok, blink = pcall(require, "blink.cmp")
  if ok and blink.is_visible() then
    blink.select_and_accept()
    return ""
  end
  local c = vim.fn.col(".")
  for _, target in ipairs(COLUMNS) do
    if target > c then
      return string.rep(" ", target - c)
    end
  end
  return "  " -- past the comment column: a small nudge
end, { buffer = true, expr = true, desc = "Merlin column tab / accept completion" })

-- --- K: symbol info popup ----------------------------------------------------
-- No LSP hover for asm, so build one: the curated 6502/TIA docs from
-- dasm_complete + the symbol's actual definition line out of the tags
-- database (vcs.h/macro.h lines carry their own trailing ';' comments).
vim.keymap.set("n", "K", function()
  local w = vim.fn.expand("<cword>")
  if w == "" then return end
  local lines = {}
  local ok, dasm = pcall(require, "dasm_complete")
  local item = ok and dasm.lookup and dasm.lookup(w)
  if item then
    lines[#lines + 1] = ("%s  [%s]"):format(item.label, item.labelDetails.description)
    vim.list_extend(lines, vim.split(item.documentation.value, "\n", { plain = true }))
  end
  for _, t in ipairs(vim.fn.taglist("^" .. vim.fn.escape(w, "\\") .. "$")) do
    -- tag cmd is the search pattern /^<definition line>$/ — show it verbatim
    local src = t.cmd:match("^/%^(.-)%$/$") or t.cmd
    src = src:gsub("%s+", " ")
    if #lines > 0 then lines[#lines + 1] = "" end
    lines[#lines + 1] = vim.fn.fnamemodify(t.filename, ":t") .. ":"
    lines[#lines + 1] = "  " .. src
  end
  if #lines == 0 then
    vim.notify("dasm: no info for '" .. w .. "'", vim.log.levels.INFO)
    return
  end
  vim.lsp.util.open_floating_preview(lines, "plaintext", { border = "rounded" })
end, { buffer = true, desc = "Symbol info (6502/TIA docs + definition line)" })

-- --- go to definition via ctags ---------------------------------------------
-- No LSP for asm, so give gd the tags treatment (gutentags keeps them fresh;
-- .gutctags in the project root makes ctags parse vcs.h/macro.h as Asm).
-- g<C-]> = :tjump — goes straight there, or lists candidates on a name clash.
vim.keymap.set("n", "gd", "g<C-]>", { buffer = true, desc = "Go to definition (tags)" })

-- --- include-file navigation ('gf' on "vcs.h") -----------------------------
-- Add the project's dasm/ folder (found by walking up) to 'path' so gf resolves
-- the quoted include filenames.
do
  local dir = vim.fn.expand("%:p:h")
  for _ = 1, 10 do
    if vim.fn.isdirectory(dir .. "/dasm") == 1 then
      -- escape spaces/commas so paths like ".../Atari 2600/..." parse as one entry
      vim.opt_local.path:append(vim.fn.escape(dir .. "/dasm", " ,"))
      break
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end
end
vim.opt_local.suffixesadd:append({ ".h", ".asm", ".inc" })
