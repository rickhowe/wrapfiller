" wrapfiller.vim: Align each line exactly between windows even if wrapped
"
" Last Change: 2023/02/19
" Version:     1.0
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023 Rick Howe
" License:     MIT

let s:save_cpo = &cpoptions
set cpo&vim

let s:wpf = {'tl': 'wrapfiller',
            \'hl': get(g:, 'VLHighlight', 'NonText'),
            \'fc': get(g:, 'VLFillchar', '<<<'),
            \'ml': get(g:, 'VLMinlines', 0)}
if has('nvim')
  let s:wpf.ns = nvim_create_namespace(s:wpf.tl)
else
  if empty(prop_type_get(s:wpf.tl))
    call prop_type_add(s:wpf.tl, {'highlight': s:wpf.hl})
  else
    call prop_type_change(s:wpf.tl, {'highlight': s:wpf.hl})
  endif
endif

function! wrapfiller#WrapFiller(op) abort
  let dw = gettabinfo(tabpagenr())[0].windows
  if 1 < len(dw)
    call s:VirtLineDel(dw)
    if get(t:, 'WrapFiller', get(g:, 'WrapFiller', 1))
      let aw = filter(copy(dw), 'getwinvar(v:val, "&" . a:op)')
      if 1 < len(aw) | call s:VirtLineAdd(aw) | endif
    endif
  endif
endfunction

function! s:VirtLineAdd(wd) abort
  " count the number of screen lines on each line ([ln-1, -1] for diff_filler)
  let do = &diffopt | let nf = (do !~ 'filler')
  if nf | let &diffopt .= (!empty(do) ? ',' : '') . 'filler' | endif
  let cn = (&cpoptions =~# 'n')
  let lr = {}
  let cw = win_getid()
  for wn in a:wd
    call win_gotoid(wn)
    let ww = getwininfo(wn)[0]
    let [wt, to, lt] = [ww.width, ww.textoff, &list && &listchars =~ 'eol']
    let lr[wn] = []
    for ln in range(1, line('$') + 1)
      let rc = 1
      if &wrap
        let lc = virtcol([ln, '$']) + lt - 1
        let rc += cn ? (to + lc - 1) / wt : (lc - 1) / (wt - to)
      endif
      if &diff
        let df = diff_filler(ln)
        if 0 < df | let lr[wn] += repeat([[ln - 1, -1]], df) | endif
      endif
      let lr[wn] += [[ln, rc]]
    endfor
    unlet lr[wn][-1]
  endfor
  call win_gotoid(cw)
  if nf | let &diffopt = do | endif
  " fill virtual lines below actual line and below/above diff_filler
  let ix = 0
  while 1
    let rn = {}
    for wn in a:wd
      if ix < len(lr[wn])
        let [ln, rc] = lr[wn][ix]
        if 0 < rc | let rn[wn] = rc | endif
      endif
    endfor
    if empty(rn) | break | endif
    let mx = max(values(rn)) + s:wpf.ml
    for wn in a:wd
      if ix < len(lr[wn])
        let bn = winbufnr(wn)
        let [ln, rc] = lr[wn][ix]
        let [ln, ab] = (ln == 0) ? [1, 1] : [ln, 0]
        for nn in range((0 < rc) ? mx - rn[wn] : mx + nf - 1)
          call s:VLAdd(bn, ln, ab)
        endfor
      endif
    endfor
    let ix += 1
  endwhile
endfunction

function! s:VirtLineDel(wd) abort
  for wn in a:wd
    call s:VLDel(winbufnr(wn))
  endfor
endfunction

if has('nvim')
function! s:VLAdd(bn, ln, ab) abort
  call nvim_buf_set_extmark(a:bn, s:wpf.ns, a:ln - 1, 0,
                                \{'virt_lines': [[[s:wpf.fc, s:wpf.hl]]],
                                \'virt_lines_above': a:ab ? v:true : v:false})
endfunction

function! s:VLDel(bn) abort
  for id in nvim_buf_get_extmarks(a:bn, s:wpf.ns, 0, -1, {})
    call nvim_buf_del_extmark(a:bn, s:wpf.ns, id[0])
  endfor
endfunction
else
function! s:VLAdd(bn, ln, ab) abort
  call prop_add(a:ln, 0, {'type': s:wpf.tl, 'bufnr': a:bn, 'text': s:wpf.fc,
                                      \'text_align': a:ab ? 'above': 'below'})
endfunction

function! s:VLDel(bn) abort
  if !empty(prop_find({'type': s:wpf.tl, 'bufnr': a:bn, 'lnum': 1, 'col': 1}))
    call prop_remove({'type': s:wpf.tl, 'bufnr': a:bn, 'all': 1})
  endif
endfunction
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
