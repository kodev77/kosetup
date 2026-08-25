-- hex.nvim: binary previewer — opening a binary file (e.g. a dasm .bin ROM
-- from the repository1-c "atari noob" sessions) shows an xxd hex dump instead
-- of raw bytes; :HexToggle flips any buffer between raw and hex view, and a
-- hex-view edit is assembled back through `xxd -r` on write.
-- Needs an `xxd` binary on PATH: Arch ships it as tinyxxd (provides xxd),
-- Debian/Devuan as xxd — both live in packages/*.list.
return {
  "RaafatTurki/hex.nvim",
  lazy = false, -- binary autodetect hooks BufReadPre; lazy-loading would miss it
  opts = {},
  keys = {
    { "<leader>hx", "<cmd>HexToggle<cr>", desc = "Hex view (toggle)" },
  },
}
