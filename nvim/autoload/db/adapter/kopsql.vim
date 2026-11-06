" Postgres adapter for vim-dadbod: the stock one, with query output squashed.
"
" psql's aligned output pads every cell to its column's widest value. One huge
" HTML/JSON value (~800K chars) made a 200-row result 337 MB of spaces, which
" took minutes to load and format. Runs of 64+ spaces (cell padding) or dashes
" (the header rule) are collapsed to one before nvim reads the output: that
" result drops to 4.4 MB with every value kept whole, so <CR> expand still
" shows it in full. The formatter splits cells on "|", not by position, so the
" squashed lines parse the same. Side effect: a value that itself holds 64+
" spaces or dashes in a row shows them as one.
"
" Only query output (filter/input) goes through the squash; everything else is
" the stock adapter. Selected in plugins_work/dadbod-ui.lua. perl rather than
" sed: 6x faster on that result (0.75s vs 4.4s), same output.

function! s:squash(cmd) abort
  return ['bash', '-c', 'set -o pipefail; "$@" | perl -pe "s/ {64,}/ /g; s/-{64,}/-/g"', 'kopsql'] + a:cmd
endfunction

function! db#adapter#kopsql#canonicalize(url) abort
  return db#adapter#postgresql#canonicalize(a:url)
endfunction

function! db#adapter#kopsql#interactive(url, ...) abort
  return call('db#adapter#postgresql#interactive', [a:url] + a:000)
endfunction

function! db#adapter#kopsql#filter(url) abort
  return s:squash(db#adapter#postgresql#filter(a:url))
endfunction

function! db#adapter#kopsql#input(url, in) abort
  return s:squash(db#adapter#postgresql#input(a:url, a:in))
endfunction

function! db#adapter#kopsql#complete_database(url) abort
  return db#adapter#postgresql#complete_database(a:url)
endfunction

function! db#adapter#kopsql#complete_opaque(url) abort
  return db#adapter#postgresql#complete_opaque(a:url)
endfunction

function! db#adapter#kopsql#tables(url) abort
  return db#adapter#postgresql#tables(a:url)
endfunction
