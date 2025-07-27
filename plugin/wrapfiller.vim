" wrapfiller.vim: Align each wrapped line virtually between windows
"
" Last Change: 2025/07/27
" Version:     2.3
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023-2025 Rick Howe
" License:     MIT

if exists('g:loaded_wrapfiller') ||
            \!(has('textprop') && has('patch-9.0.1067') || has('nvim-0.6.0'))
  finish
endif
let g:loaded_wrapfiller = 2.3

let s:save_cpo = &cpoptions
set cpo&vim

let s:op = get(g:, 'WrapFillerOpts', 'diff,list')
call execute(['augroup wrapfiller', 'autocmd!',
              \'autocmd VimEnter * ++once call s:TriggerWrapFiller(0)',
              \'autocmd OptionSet ' . s:op . ' call s:TriggerWrapFiller()',
                                                              \'augroup END'])

function! s:TriggerWrapFiller(...) abort
  if a:0
    for op in split(s:op, ',')
      if eval('&' . op) | call wrapfiller#WrapFiller(op) | break | endif
    endfor
  else
    if v:option_old != v:option_new
      call wrapfiller#WrapFiller(expand('<amatch>'))
    endif
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
