-- blink.cmp completion source for 6502 / DASM / Atari 2600 assembly.
-- Two layers:
--   1. Curated core — the keyword sets after/syntax/asm.vim highlights (6502
--      mnemonics, DASM directives, TIA/RIOT registers), each with a one-line
--      doc. This vocabulary is frozen hardware/assembler surface, so a
--      hardcoded list with explanations beats parsing docless files.
--   2. Include scanner — symbols really defined in the files the current
--      buffer `include`s (macros via MAC, equates via = / EQU / ds), resolved
--      through the buffer-local 'path' that after/ftplugin/asm.lua sets up
--      (same lookup as `gf`). Trailing ';' comments become the docs. So
--      CLEAN_START from macro.h — and your own constants — complete too.
-- Wired up per-filetype in lua/plugins/blink-dasm.lua.

local KIND = vim.lsp.protocol.CompletionItemKind
local DATA = {}

local function add(kind, detail, entries, upper)
  for word, doc in pairs(entries) do
    DATA[#DATA + 1] = {
      label = upper and word:upper() or word,
      kind = kind,
      labelDetails = { description = detail },
      documentation = { kind = "plaintext", value = doc },
    }
  end
end

-- --- 6502 mnemonics (completed in retro ALL-CAPS; DASM doesn't care) --------
add(KIND.Keyword, "6502", {
  adc = "Add memory to accumulator with carry",
  ["and"] = "AND memory with accumulator",
  asl = "Arithmetic shift left one bit",
  bcc = "Branch if carry clear",
  bcs = "Branch if carry set",
  beq = "Branch if equal (zero flag set)",
  bit = "Test bits in memory with accumulator",
  bmi = "Branch if minus (negative flag set)",
  bne = "Branch if not equal (zero flag clear)",
  bpl = "Branch if plus (negative flag clear)",
  brk = "Force break / software interrupt",
  bvc = "Branch if overflow clear",
  bvs = "Branch if overflow set",
  clc = "Clear carry flag",
  cld = "Clear decimal mode",
  cli = "Clear interrupt disable",
  clv = "Clear overflow flag",
  cmp = "Compare memory with accumulator",
  cpx = "Compare memory with X register",
  cpy = "Compare memory with Y register",
  dec = "Decrement memory by one",
  dex = "Decrement X register by one",
  dey = "Decrement Y register by one",
  eor = "Exclusive-OR memory with accumulator",
  inc = "Increment memory by one",
  inx = "Increment X register by one",
  iny = "Increment Y register by one",
  jmp = "Jump to address",
  jsr = "Jump to subroutine (pushes return address)",
  lda = "Load accumulator from memory",
  ldx = "Load X register from memory",
  ldy = "Load Y register from memory",
  lsr = "Logical shift right one bit",
  nop = "No operation",
  ora = "OR memory with accumulator",
  pha = "Push accumulator on stack",
  php = "Push processor status on stack",
  pla = "Pull accumulator from stack",
  plp = "Pull processor status from stack",
  rol = "Rotate left one bit through carry",
  ror = "Rotate right one bit through carry",
  rti = "Return from interrupt",
  rts = "Return from subroutine",
  sbc = "Subtract memory from accumulator with borrow",
  sec = "Set carry flag",
  sed = "Set decimal mode",
  sei = "Set interrupt disable",
  sta = "Store accumulator in memory",
  stx = "Store X register in memory",
  sty = "Store Y register in memory",
  tax = "Transfer accumulator to X",
  tay = "Transfer accumulator to Y",
  tsx = "Transfer stack pointer to X",
  txa = "Transfer X to accumulator",
  txs = "Transfer X to stack pointer",
  tya = "Transfer Y to accumulator",
}, true)

-- --- DASM directives / pseudo-ops -------------------------------------------
add(KIND.Module, "DASM", {
  processor = "Select target CPU (e.g. processor 6502)",
  include = "Include another source file",
  incdir = "Add a directory to the include search path",
  seg = "Start / switch to a segment (seg.u = uninitialised)",
  org = "Set origin (assembly address)",
  rorg = "Set relocatable origin",
  mac = "Begin macro definition (end with endm)",
  endm = "End macro definition",
  ["repeat"] = "Begin repeat block (end with repend)",
  repend = "End repeat block",
  ["if"] = "Conditional assembly (end with endif/eif)",
  ["else"] = "Conditional assembly: else branch",
  endif = "End conditional assembly",
  eif = "End conditional assembly (short form)",
  ifconst = "Assemble if symbol is defined",
  ifnconst = "Assemble if symbol is NOT defined",
  echo = "Print message during assembly",
  err = "Raise an assembly error",
  subroutine = "Start a new local-label scope",
  set = "Assign a (reassignable) value to a symbol",
  equ = "Equate a symbol to a constant value",
  align = "Align to a byte boundary",
  ["end"] = "End of source (stop assembling)",
  hex = "Emit raw hex bytes",
  dc = "Define constant byte/word/long data",
  ds = "Define storage (reserve space)",
  dv = "Define data through an EQM expression",
  byte = "Emit byte data (dc.b)",
  word = "Emit word data (dc.w)",
  long = "Emit long data (dc.l)",
}, true)

-- --- TIA write registers (from vcs.h) ---------------------------------------
add(KIND.Constant, "TIA", {
  VSYNC = "Vertical sync set/clear (start of frame)",
  VBLANK = "Vertical blank set/clear (also input latches)",
  WSYNC = "Wait for leading edge of horizontal blank (strobe)",
  RSYNC = "Reset horizontal sync counter (strobe)",
  NUSIZ0 = "Number-size of player 0 / missile 0",
  NUSIZ1 = "Number-size of player 1 / missile 1",
  COLUP0 = "Colour-luminance of player 0 / missile 0",
  COLUP1 = "Colour-luminance of player 1 / missile 1",
  COLUPF = "Colour-luminance of playfield / ball",
  COLUBK = "Colour-luminance of background",
  CTRLPF = "Playfield control (reflect, score, priority, ball size)",
  REFP0 = "Reflect player 0",
  REFP1 = "Reflect player 1",
  PF0 = "Playfield register byte 0 (leftmost 4 bits)",
  PF1 = "Playfield register byte 1",
  PF2 = "Playfield register byte 2",
  RESP0 = "Reset (position) player 0 (strobe)",
  RESP1 = "Reset (position) player 1 (strobe)",
  RESM0 = "Reset (position) missile 0 (strobe)",
  RESM1 = "Reset (position) missile 1 (strobe)",
  RESBL = "Reset (position) ball (strobe)",
  AUDC0 = "Audio control (waveform) channel 0",
  AUDC1 = "Audio control (waveform) channel 1",
  AUDF0 = "Audio frequency divider channel 0",
  AUDF1 = "Audio frequency divider channel 1",
  AUDV0 = "Audio volume channel 0",
  AUDV1 = "Audio volume channel 1",
  GRP0 = "Graphics (bitmap) player 0",
  GRP1 = "Graphics (bitmap) player 1",
  ENAM0 = "Enable missile 0",
  ENAM1 = "Enable missile 1",
  ENABL = "Enable ball",
  HMP0 = "Horizontal motion player 0",
  HMP1 = "Horizontal motion player 1",
  HMM0 = "Horizontal motion missile 0",
  HMM1 = "Horizontal motion missile 1",
  HMBL = "Horizontal motion ball",
  VDELP0 = "Vertical delay player 0",
  VDELP1 = "Vertical delay player 1",
  VDELBL = "Vertical delay ball",
  RESMP0 = "Reset missile 0 to player 0",
  RESMP1 = "Reset missile 1 to player 1",
  HMOVE = "Apply horizontal motion (strobe, after WSYNC)",
  HMCLR = "Clear horizontal motion registers (strobe)",
  CXCLR = "Clear collision latches (strobe)",
})

-- --- TIA read registers (collisions / input) --------------------------------
add(KIND.Constant, "TIA read", {
  CXM0P = "Collision: missile 0 with players",
  CXM1P = "Collision: missile 1 with players",
  CXP0FB = "Collision: player 0 with playfield/ball",
  CXP1FB = "Collision: player 1 with playfield/ball",
  CXM0FB = "Collision: missile 0 with playfield/ball",
  CXM1FB = "Collision: missile 1 with playfield/ball",
  CXBLPF = "Collision: ball with playfield",
  CXPPMM = "Collision: player-player / missile-missile",
  INPT0 = "Paddle 0 input (dumped)",
  INPT1 = "Paddle 1 input (dumped)",
  INPT2 = "Paddle 2 input (dumped)",
  INPT3 = "Paddle 3 input (dumped)",
  INPT4 = "Joystick 0 fire button (latched)",
  INPT5 = "Joystick 1 fire button (latched)",
})

-- --- RIOT (PIA 6532) ---------------------------------------------------------
add(KIND.Constant, "RIOT", {
  SWCHA = "Port A: joystick directions (both players)",
  SWACNT = "Port A data-direction register",
  SWCHB = "Port B: console switches (select/reset/difficulty)",
  SWBCNT = "Port B data-direction register",
  INTIM = "Read timer value",
  TIM1T = "Set timer, 1-cycle interval",
  TIM8T = "Set timer, 8-cycle interval",
  TIM64T = "Set timer, 64-cycle interval (the kernel staple)",
  T1024T = "Set timer, 1024-cycle interval",
})

-- --- include scanner ---------------------------------------------------------

local CURATED = {}
for _, item in ipairs(DATA) do
  CURATED[item.label:lower()] = true
end

local cache = {} -- fullpath -> { mtime, items }

-- Extract completion items from one included file: MAC macros, and col-0
-- symbols defined via '=', EQU or ds. A trailing ';' comment becomes the doc.
local function parse_include_file(path)
  local stat = (vim.uv or vim.loop).fs_stat(path)
  if not stat then return {} end
  local hit = cache[path]
  if hit and hit.mtime == stat.mtime.sec then return hit.items end

  local items = {}
  local filename = vim.fn.fnamemodify(path, ":t")
  local ok, lines = pcall(vim.fn.readfile, path)
  if ok then
    for _, line in ipairs(lines) do
      local sym = line:match("^%s*[Mm][Aa][Cc]%s+([%w_]+)")
      local kind = sym and KIND.Function
      if not sym then
        local s, rest = line:match("^([%a_][%w_]*)%s+(.*)$")
        if s and (rest:match("^=") or rest:match("^[Ee][Qq][Uu]%s") or rest:match("^[Dd][Ss]%s")) then
          sym, kind = s, KIND.Constant
        end
      end
      if sym and not CURATED[sym:lower()] then
        local comment = line:match(";%s*(.-)%s*$")
        items[#items + 1] = {
          label = sym,
          kind = kind,
          labelDetails = { description = filename },
          documentation = (comment and comment ~= "")
              and { kind = "plaintext", value = comment }
            or nil,
        }
      end
    end
  end
  cache[path] = { mtime = stat.mtime.sec, items = items }
  return items
end

-- Symbols from every file the buffer `include`s, resolved via the buffer's
-- 'path' (which the asm ftplugin points at the project's dasm/ folder).
local function scan_includes(bufnr)
  local out, seen = {}, {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local inc = line:match('^%s*[Ii][Nn][Cc][Ll][Uu][Dd][Ee]%s+"([^"]+)"')
      or line:match("^%s*[Ii][Nn][Cc][Ll][Uu][Dd][Ee]%s+([%w_./]+)")
    if inc and not seen[inc] then
      seen[inc] = true
      local found = vim.fn.findfile(inc)
      if found ~= "" then
        vim.list_extend(out, parse_include_file(vim.fn.fnamemodify(found, ":p")))
      end
    end
  end
  return out
end

-- --- per-bit layouts (Stella Programmer's Guide) ------------------------------
-- Appended to the matching register's documentation: shows WHICH bits are
-- wired and what each does. Unlisted bits are not connected.

local STROBE = "strobe: ANY write triggers it — the value is ignored"
local BITS = {
  VSYNC  = "D1     vertical sync on/off (write 2 = on, 0 = off; hold 3 lines)",
  VBLANK = "D1     blank video (1 = beam off)\nD6     latch INPT4/5 fire buttons (0 also clears latches)\nD7     dump INPT0-3 to ground (paddle discharge)",
  CTRLPF = "D0     REF: reflect right half (0 = repeat)\nD1     SCORE: PF colour = COLUP0 left / COLUP1 right\nD2     PFP: playfield+ball priority over players\nD4-D5  ball width: 00=1 01=2 10=4 11=8 clocks",
  PF0    = "D4-D7  pixels 0-3 of the half, REVERSED: D4 = leftmost (D0-D3 unused)",
  PF1    = "D7-D0  pixels 4-11, normal order: D7 = leftmost",
  PF2    = "D0-D7  pixels 12-19, REVERSED: D0 = leftmost",
  NUSIZ0 = "D0-D2  player copies/size: 0=one 1=two close 2=two med 3=three close\n       4=two wide 5=double-width 6=three med 7=quad-width\nD4-D5  missile width: 1/2/4/8 clocks",
  REFP0  = "D3     1 = reflect player sprite",
  ENAM0  = "D1     1 = enable missile",
  ENABL  = "D1     1 = enable ball",
  VDELP0 = "D0     1 = vertical delay (update on other player's GRPx write)",
  VDELBL = "D0     1 = vertical delay ball",
  RESMP0 = "D1     1 = hide missile + lock it to player centre",
  HMP0   = "D4-D7  signed motion -8..+7, applied at HMOVE (positive = left)",
  AUDC0  = "D0-D3  waveform/noise type (0 = silent, 4/C = pure tone, 8 = white noise)",
  AUDF0  = "D0-D4  frequency divider (~30kHz / (n+1))",
  AUDV0  = "D0-D3  volume (0 = off .. 15 = max)",
  SWCHA  = "D4-D7  P0 stick: up D4, down D5, left D6, right D7 (0 = pushed)\nD0-D3  P1 stick, same order",
  SWCHB  = "D0     reset switch (0 = pressed)\nD1     select switch (0 = pressed)\nD3     0 = B&W, 1 = colour\nD6/D7  P0/P1 difficulty (1 = A/pro)",
  INPT4  = "D7     fire button, 0 = pressed (latched low if VBLANK D6 set)",
  CXM0P  = "D7 M0-P1 · D6 M0-P0   (collision latches; CXCLR clears)",
  CXM1P  = "D7 M1-P0 · D6 M1-P1   (collision latches; CXCLR clears)",
  CXP0FB = "D7 P0-PF · D6 P0-BL   (collision latches; CXCLR clears)",
  CXP1FB = "D7 P1-PF · D6 P1-BL   (collision latches; CXCLR clears)",
  CXM0FB = "D7 M0-PF · D6 M0-BL   (collision latches; CXCLR clears)",
  CXM1FB = "D7 M1-PF · D6 M1-BL   (collision latches; CXCLR clears)",
  CXBLPF = "D7 BL-PF              (collision latch; CXCLR clears)",
  CXPPMM = "D7 P0-P1 · D6 M0-M1   (collision latches; CXCLR clears)",
  WSYNC = STROBE, RSYNC = STROBE, RESP0 = STROBE, RESP1 = STROBE,
  RESM0 = STROBE, RESM1 = STROBE, RESBL = STROBE, HMOVE = STROBE,
  HMCLR = STROBE, CXCLR = STROBE,
}
-- identical-layout twins
BITS.NUSIZ1, BITS.REFP1, BITS.ENAM1, BITS.VDELP1, BITS.RESMP1 =
  BITS.NUSIZ0, BITS.REFP0, BITS.ENAM0, BITS.VDELP0, BITS.RESMP0
BITS.HMP1, BITS.HMM0, BITS.HMM1, BITS.HMBL = BITS.HMP0, BITS.HMP0, BITS.HMP0, BITS.HMP0
BITS.AUDC1, BITS.AUDF1, BITS.AUDV1 = BITS.AUDC0, BITS.AUDF0, BITS.AUDV0
BITS.INPT5 = BITS.INPT4
local COLORBITS = "D4-D7  hue · D1-D3  luminance (D0 ignored) — e.g. $C6 = hue C, lum 3"
BITS.COLUP0, BITS.COLUP1, BITS.COLUPF, BITS.COLUBK =
  COLORBITS, COLORBITS, COLORBITS, COLORBITS

for _, it in ipairs(DATA) do
  local b = BITS[it.label]
  if b then
    it.documentation.value = it.documentation.value .. "\n\nbits:\n" .. b
  end
end

-- --- opcode encodings (per addressing mode) -----------------------------------
-- Appended to each 6502 mnemonic's documentation: the actual opcode byte the
-- assembler emits for each addressing mode, in hex and binary.

local function bin8(n)
  local s = ""
  for i = 7, 0, -1 do
    s = s .. tostring(math.floor(n / 2 ^ i) % 2)
  end
  return "%" .. s
end

local OPCODES = {
  adc = { { "#imm", 0x69 }, { "zp", 0x65 }, { "zp,X", 0x75 }, { "abs", 0x6D }, { "abs,X", 0x7D }, { "abs,Y", 0x79 }, { "(ind,X)", 0x61 }, { "(ind),Y", 0x71 } },
  ["and"] = { { "#imm", 0x29 }, { "zp", 0x25 }, { "zp,X", 0x35 }, { "abs", 0x2D }, { "abs,X", 0x3D }, { "abs,Y", 0x39 }, { "(ind,X)", 0x21 }, { "(ind),Y", 0x31 } },
  asl = { { "A", 0x0A }, { "zp", 0x06 }, { "zp,X", 0x16 }, { "abs", 0x0E }, { "abs,X", 0x1E } },
  bcc = { { "rel", 0x90 } },
  bcs = { { "rel", 0xB0 } },
  beq = { { "rel", 0xF0 } },
  bit = { { "zp", 0x24 }, { "abs", 0x2C } },
  bmi = { { "rel", 0x30 } },
  bne = { { "rel", 0xD0 } },
  bpl = { { "rel", 0x10 } },
  brk = { { "impl", 0x00 } },
  bvc = { { "rel", 0x50 } },
  bvs = { { "rel", 0x70 } },
  clc = { { "impl", 0x18 } },
  cld = { { "impl", 0xD8 } },
  cli = { { "impl", 0x58 } },
  clv = { { "impl", 0xB8 } },
  cmp = { { "#imm", 0xC9 }, { "zp", 0xC5 }, { "zp,X", 0xD5 }, { "abs", 0xCD }, { "abs,X", 0xDD }, { "abs,Y", 0xD9 }, { "(ind,X)", 0xC1 }, { "(ind),Y", 0xD1 } },
  cpx = { { "#imm", 0xE0 }, { "zp", 0xE4 }, { "abs", 0xEC } },
  cpy = { { "#imm", 0xC0 }, { "zp", 0xC4 }, { "abs", 0xCC } },
  dec = { { "zp", 0xC6 }, { "zp,X", 0xD6 }, { "abs", 0xCE }, { "abs,X", 0xDE } },
  dex = { { "impl", 0xCA } },
  dey = { { "impl", 0x88 } },
  eor = { { "#imm", 0x49 }, { "zp", 0x45 }, { "zp,X", 0x55 }, { "abs", 0x4D }, { "abs,X", 0x5D }, { "abs,Y", 0x59 }, { "(ind,X)", 0x41 }, { "(ind),Y", 0x51 } },
  inc = { { "zp", 0xE6 }, { "zp,X", 0xF6 }, { "abs", 0xEE }, { "abs,X", 0xFE } },
  inx = { { "impl", 0xE8 } },
  iny = { { "impl", 0xC8 } },
  jmp = { { "abs", 0x4C }, { "(ind)", 0x6C } },
  jsr = { { "abs", 0x20 } },
  lda = { { "#imm", 0xA9 }, { "zp", 0xA5 }, { "zp,X", 0xB5 }, { "abs", 0xAD }, { "abs,X", 0xBD }, { "abs,Y", 0xB9 }, { "(ind,X)", 0xA1 }, { "(ind),Y", 0xB1 } },
  ldx = { { "#imm", 0xA2 }, { "zp", 0xA6 }, { "zp,Y", 0xB6 }, { "abs", 0xAE }, { "abs,Y", 0xBE } },
  ldy = { { "#imm", 0xA0 }, { "zp", 0xA4 }, { "zp,X", 0xB4 }, { "abs", 0xAC }, { "abs,X", 0xBC } },
  lsr = { { "A", 0x4A }, { "zp", 0x46 }, { "zp,X", 0x56 }, { "abs", 0x4E }, { "abs,X", 0x5E } },
  nop = { { "impl", 0xEA } },
  ora = { { "#imm", 0x09 }, { "zp", 0x05 }, { "zp,X", 0x15 }, { "abs", 0x0D }, { "abs,X", 0x1D }, { "abs,Y", 0x19 }, { "(ind,X)", 0x01 }, { "(ind),Y", 0x11 } },
  pha = { { "impl", 0x48 } },
  php = { { "impl", 0x08 } },
  pla = { { "impl", 0x68 } },
  plp = { { "impl", 0x28 } },
  rol = { { "A", 0x2A }, { "zp", 0x26 }, { "zp,X", 0x36 }, { "abs", 0x2E }, { "abs,X", 0x3E } },
  ror = { { "A", 0x6A }, { "zp", 0x66 }, { "zp,X", 0x76 }, { "abs", 0x6E }, { "abs,X", 0x7E } },
  rti = { { "impl", 0x40 } },
  rts = { { "impl", 0x60 } },
  sbc = { { "#imm", 0xE9 }, { "zp", 0xE5 }, { "zp,X", 0xF5 }, { "abs", 0xED }, { "abs,X", 0xFD }, { "abs,Y", 0xF9 }, { "(ind,X)", 0xE1 }, { "(ind),Y", 0xF1 } },
  sec = { { "impl", 0x38 } },
  sed = { { "impl", 0xF8 } },
  sei = { { "impl", 0x78 } },
  sta = { { "zp", 0x85 }, { "zp,X", 0x95 }, { "abs", 0x8D }, { "abs,X", 0x9D }, { "abs,Y", 0x99 }, { "(ind,X)", 0x81 }, { "(ind),Y", 0x91 } },
  stx = { { "zp", 0x86 }, { "zp,Y", 0x96 }, { "abs", 0x8E } },
  sty = { { "zp", 0x84 }, { "zp,X", 0x94 }, { "abs", 0x8C } },
  tax = { { "impl", 0xAA } },
  tay = { { "impl", 0xA8 } },
  tsx = { { "impl", 0xBA } },
  txa = { { "impl", 0x8A } },
  txs = { { "impl", 0x9A } },
  tya = { { "impl", 0x98 } },
}

for _, it in ipairs(DATA) do
  local ops = OPCODES[it.label:lower()]
  if ops then
    local rows = {}
    for _, m in ipairs(ops) do
      rows[#rows + 1] = string.format("%-8s $%02X  %s", m[1], m[2], bin8(m[2]))
    end
    it.documentation.value = it.documentation.value
      .. "\n\nopcodes:\n" .. table.concat(rows, "\n")
  end
end

-- --- blink.cmp source --------------------------------------------------------

local source = {}

function source.new()
  return setmetatable({}, { __index = source })
end

function source:enabled()
  return vim.bo.filetype == "asm"
end

-- Doc lookup for the curated sets (used by the asm ftplugin's K mapping).
local INDEX
function source.lookup(word)
  if not INDEX then
    INDEX = {}
    for _, it in ipairs(DATA) do
      INDEX[it.label] = it
    end
  end
  return INDEX[word] or INDEX[word:upper()] or INDEX[word:lower()]
end

function source:get_completions(ctx, callback)
  local items = vim.list_slice(DATA)
  local ok, scanned = pcall(scan_includes, ctx.bufnr or vim.api.nvim_get_current_buf())
  if ok then
    vim.list_extend(items, scanned)
  end
  callback({
    is_incomplete_forward = false,
    is_incomplete_backward = false,
    items = items,
  })
end

return source
