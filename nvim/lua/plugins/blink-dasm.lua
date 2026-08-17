-- Blink.cmp integration: register the local 6502/DASM/TIA keyword source
-- (lua/dasm_complete.lua) for assembly buffers, alongside the defaults.
return {
  "saghen/blink.cmp",
  optional = true,
  opts = {
    sources = {
      per_filetype = {
        asm = { inherit_defaults = true, "dasm" },
      },
      providers = {
        dasm = {
          name = "6502",
          module = "dasm_complete",
          -- rank keywords/registers above plain buffer words
          score_offset = 5,
        },
      },
    },
  },
}
