" wrapfiller.vim: Align each line exactly between windows even if wrapped
"
" Last Change: 2023/05/22
" Version:     2.0
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023 Rick Howe
" License:     MIT

if exists('g:loaded_wrapfiller') ||
            \!(has('textprop') && has('patch-9.0.1067') || has('nvim-0.6.0'))
  finish
endif
let g:loaded_wrapfiller = 2.0

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
    call wrapfiller#WrapFiller(expand('<amatch>'))
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
