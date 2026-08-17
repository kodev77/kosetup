" 6502 / DASM highlighting, layered on top of nvim's built-in `asm` syntax.
" Lives in after/syntax so it augments rather than replaces. 6502 assembly is
" case-insensitive (LDA == lda), so match case-insensitively.
syntax case ignore

" --- 6502 mnemonics --------------------------------------------------------
syntax keyword dasm6502Opcode adc and asl bcc bcs beq bit bmi bne bpl brk bvc bvs
syntax keyword dasm6502Opcode clc cld cli clv cmp cpx cpy dec dex dey eor inc inx
syntax keyword dasm6502Opcode iny jmp jsr lda ldx ldy lsr nop ora pha php pla plp
syntax keyword dasm6502Opcode rol ror rti rts sbc sec sed sei sta stx sty tax tay
syntax keyword dasm6502Opcode tsx txa txs tya

" --- DASM directives / pseudo-ops ------------------------------------------
syntax keyword dasmDirective processor include incdir seg org rorg mac endm
syntax keyword dasmDirective repeat repend if else endif eif ifconst ifnconst
syntax keyword dasmDirective echo err subroutine set equ align end hex
syntax keyword dasmDirective dc ds dv byte word long
syntax match   dasmDirective /\.\<\%(byte\|word\|long\|dc\|ds\|dv\|align\)\>/

" --- TIA / RIOT register names (from vcs.h) --------------------------------
syntax keyword dasmTiaReg VSYNC VBLANK WSYNC RSYNC NUSIZ0 NUSIZ1 COLUP0 COLUP1
syntax keyword dasmTiaReg COLUPF COLUBK CTRLPF REFP0 REFP1 PF0 PF1 PF2 RESP0 RESP1
syntax keyword dasmTiaReg RESM0 RESM1 RESBL AUDC0 AUDC1 AUDF0 AUDF1 AUDV0 AUDV1
syntax keyword dasmTiaReg GRP0 GRP1 ENAM0 ENAM1 ENABL HMP0 HMP1 HMM0 HMM1 HMBL
syntax keyword dasmTiaReg VDELP0 VDELP1 VDELBL RESMP0 RESMP1 HMOVE HMCLR CXCLR
syntax keyword dasmTiaReg CXM0P CXM1P CXP0FB CXP1FB CXM0FB CXM1FB CXBLPF CXPPMM
syntax keyword dasmTiaReg INPT0 INPT1 INPT2 INPT3 INPT4 INPT5
syntax keyword dasmTiaReg SWCHA SWACNT SWCHB SWBCNT INTIM TIM1T TIM8T TIM64T T1024T

" --- numbers ---------------------------------------------------------------
syntax match dasmHexNumber /\$[0-9A-Fa-f]\+/
syntax match dasmBinNumber /%[01]\+/
syntax match dasmDecNumber /\<\d\+\>/
syntax match dasmImmediate /#/

" --- comments (DASM uses ';') ---------------------------------------------
syntax match dasmComment /;.*$/ contains=@Spell

" Colours: set BOTH cterm (RIDE / 16-colour mode, the default here) and gui
" (truecolor mode). cterm uses ANSI colour NAMES so tokens still ride the
" terminal palette (matching colorride). This is needed because the built-in
" `default` scheme leaves Statement/PreProc/Number without cterm colours.
highlight dasm6502Opcode ctermfg=Yellow  guifg=#e5c07b
" Directives on slot 2 (dim green) — labels own the bright green (10).
highlight dasmDirective  ctermfg=2       guifg=#7fa85c
highlight dasmTiaReg     ctermfg=Cyan    guifg=#56b6c2
" Numbers on slot 6 (dim teal) — TIA regs own the bright teal (Cyan = 14).
highlight dasmHexNumber  ctermfg=6       guifg=#7fdbca
highlight dasmBinNumber  ctermfg=6       guifg=#7fdbca
highlight dasmDecNumber  ctermfg=6       guifg=#7fdbca
" Immediate marker '#' on slot 14 (bright teal) — pairs with the literal's
" dim teal (6) so '#0' / '#$1E' read as one flowing token.
highlight dasmImmediate ctermfg=14      guifg=#56b6c2
highlight default link dasmComment   Comment

" Recolour the STOCK asm groups (scoped here, not via String/Identifier, so
" other filetypes keep their colours): strings red, labels bright blue.
highlight asmString     ctermfg=9  guifg=#e06c75
highlight asmIdentifier ctermfg=12 guifg=#61afef
