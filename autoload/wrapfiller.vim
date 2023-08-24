" wrapfiller.vim: Align each line exactly between windows even if wrapped
"
" Last Change: 2023/08/24
" Version:     2.1
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023 Rick Howe
" License:     MIT

let s:save_cpo = &cpoptions
set cpo&vim

let s:wpf = {'tl': 'wrapfiller', 'ht': {'list': ['NonText', '<<<'],
                      \'diff': ['DiffDelete', repeat((&fillchars =~ 'diff') ?
                        \matchstr(&fillchars, 'diff:\zs.') : '-', &columns)]}}
if has('nvim')
  let s:wpf.ns = nvim_create_namespace(s:wpf.tl)
else
  for [tn, ht] in items(s:wpf.ht)
    let tn = s:wpf.tl . '_' . tn
    if !empty(prop_type_get(tn))
      call prop_type_delete(tn)
    endif
    call prop_type_add(tn, {'highlight': ht[0]})
  endfor
endif

function! wrapfiller#WrapFiller(op) abort
  let wd = gettabinfo(tabpagenr())[0].windows
  call s:VirtLineDel(wd, 1)
  if get(t:, 'WrapFiller', get(g:, 'WrapFiller', 1))
    for op in ['diff', 'list']
      let wx = filter(copy(wd), 'getwinvar(v:val, "&" . op)')
      if 1 < len(wx) | call s:VirtLineAdd(wx, op) | break | endif
    endfor
  endif
endfunction

function! s:VirtLineAdd(wd, op) abort
  let zz = {} | for wn in a:wd | let zz[wn] = {} | endfor
  if a:op == 'diff'
    if &diffopt !~ 'filler'
      echohl WarningMsg | echo "'filler' not found in &diffopt" | echohl None
      return
    endif
    " set a max &foldlevel commonly in all windows
    let zz.fv = -1
    for wn in a:wd
      let zz[wn].fv = getwinvar(wn, '&foldlevel')
      if zz.fv < zz[wn].fv | let zz.fv = zz[wn].fv | endif
    endfor
    for wn in a:wd | call setwinvar(wn, '&foldlevel', zz.fv) | endfor
    " find a common diff unhighlighted base start line between windows
    let tb = {}
    let [tn, bn] = [0, 0]
    for wn in a:wd
      call win_execute(wn, 'let [fl, tl, bl, ll] =
                                    \[1, line("w0"), line("w$"), line("$")]')
      let wh = winheight(wn)
      let [tl, bl] = [max([tl - wh, 1]), min([bl + wh, ll])]
      let se = getwinvar(wn, s:wpf.tl)
      if !empty(se)
        let [fl, ll] = (se.sl <= tl) ? [se.sl, ll] : [fl, se.sl]
      endif
      let [tn, bn] += [tl - fl, ll - tl]
      let tb[wn] = {'fl': fl, 'tl': tl, 'bl': bl, 'll': ll}
    endfor
    if tn <= bn
      for wn in a:wd
        call win_execute(wn, 'let eh = s:GetCleanLines(tb[wn].fl, tb[wn].tl)')
        let tb[wn].eh = eh | let tb[wn].en = len(eh)
      endfor
      let ex = min(map(values(tb), 'v:val.en'))
      let zz.sx = (ex == 0)
      for wn in a:wd
        let zz[wn].sl = (0 < ex) ? tb[wn].eh[ex - 1] : 1
        let zz[wn].el = tb[wn].bl
      endfor
    else
      for wn in a:wd
        call win_execute(wn, 'let eh = s:GetCleanLines(tb[wn].tl, tb[wn].ll)')
        let tb[wn].eh = eh | let tb[wn].en = len(eh)
      endfor
      let ex = max(map(values(tb), 'v:val.en')) + 1
      let zz.sx = 0
      for wn in a:wd
        let eh = []
        let tl = tb[wn].tl
        let rc = ex - tb[wn].en
        while 0 < rc
          let tl -= rc
          call win_execute(wn, 'let dh = s:GetCleanLines(tl, tl + rc - 1)')
          let eh = dh + eh
          let rc -= len(dh)
        endwhile
        let [zz[wn].sl, zz.sx] = !empty(eh) ? [eh[0], zz.sx] : [1, 1]
        let zz[wn].el = tb[wn].bl
      endfor
    endif
    " count the number of diff filler and screen rows on each line
    let lr = {}
    for wn in a:wd
      let lr[wn] = []
      let ln = zz[wn].sl
      while ln <= zz[wn].el + 1
        call win_execute(wn, 'let fl = foldlevel(ln)')
        if fl <= zz.fv
          if zz.sx || zz[wn].sl < ln
            call win_execute(wn, 'let df = diff_filler(ln)')
            if 0 < df | let lr[wn] += repeat([[-(ln - 1), 1]], df) | endif
          endif
          call win_execute(wn, 'let rc = s:CountRows(wn, ln)')
          let lr[wn] += [[ln, rc]]
        else
          call win_execute(wn, 'let fc = foldclosedend(ln)')
          if fc != -1 | let ln = fc | endif
        endif
        let ln += 1
      endwhile
      unlet lr[wn][-1]
      " reset to original &foldlevel
      call setwinvar(wn, '&foldlevel', zz[wn].fv)
    endfor
  elseif a:op == 'list'
    let [sl, el] = [v:numbermax, 0]
    for wn in a:wd
      call win_execute(wn, 'let [tl, bl, ll] =
                                        \[line("w0"), line("w$"), line("$")]')
      let wh = winheight(wn)
      let [tl, bl] = [max([tl - wh, 1]), min([bl + wh, ll])]
      if tl < sl | let sl = tl | endif
      if bl > el | let el = bl | endif
      let zz[wn].ll = ll
    endfor
    for wn in a:wd
      let zz[wn].sl = sl
      let zz[wn].el = min([el, zz[wn].ll])
    endfor
    let lr = {}
    for wn in a:wd
      let lr[wn] = []
      for ln in range(zz[wn].sl, zz[wn].el)
        call win_execute(wn, 'let rc = s:CountRows(wn, ln)')
        let lr[wn] += [[ln, rc]]
      endfor
    endfor
  endif
  " compare rows between windows and count required virtual lines
  let vl = {} | for wn in a:wd | let vl[wn] = [] | endfor
  let ix = 0
  while 1
    let rn = {}
    for wn in a:wd
      if ix < len(lr[wn]) | let rn[wn] = lr[wn][ix][1] | endif
    endfor
    if len(rn) < 2 | break | endif
    let rx = max(values(rn))
    for wn in keys(rn)
      let rc = rx - rn[wn]
      if 0 < rc | let vl[wn] += [[rc, lr[wn][ix][0]]] | endif
    endfor
    let ix += 1
  endwhile
  " draw virtual lines on each window and set WinScrolled event
  for wn in a:wd
    for [rc, ln] in vl[wn]
      let [ln, ab] = (ln == 0) ? [1, 1] : [abs(ln), 0]
      while 0 < rc | call s:VLAdd(wn, a:op, ln, ab) | let rc -= 1 | endwhile
    endfor
    call execute('autocmd ' . s:wpf.tl . ' WinScrolled <buffer=' .
                    \winbufnr(wn) . '> call s:VirtLineUpd(''' . a:op . ''')')
    call setwinvar(wn, s:wpf.tl, {'sl': zz[wn].sl, 'el': zz[wn].el})
  endfor
endfunction

function! s:GetCleanLines(sl, el) abort
  return filter(range(a:sl, a:el),
                        \'diff_hlID(v:val, 1) == 0 && foldlevel(v:val) == 0')
endfunction

function! s:CountRows(wn, ln) abort
  let rc = 1
  if getwinvar(a:wn, '&wrap')
    let wi = getwininfo(a:wn)[0]
    let vc = (virtcol([a:ln, '$']) - 1) +
                            \(getwinvar(a:wn, '&list') && &listchars =~ 'eol')
    let rc += (&cpoptions =~# 'n') ? (wi.textoff + vc - 1) / wi.width :
                                          \(vc - 1) / (wi.width - wi.textoff)
  endif
  return rc
endfunction

function! s:VirtLineDel(wd, all) abort
  for wn in a:wd
    call s:VLDel(wn)
    call execute('autocmd! ' . s:wpf.tl . ' WinScrolled <buffer=' .
                                                          \winbufnr(wn) . '>')
    if a:all
      let wv = getwinvar(wn, '')
      if has_key(wv, s:wpf.tl) | unlet wv[s:wpf.tl] | endif
    endif
  endfor
endfunction

function! s:VirtLineUpd(op) abort
  let uc = 0
  let wd = filter(gettabinfo(tabpagenr())[0].windows,
                                              \'getwinvar(v:val, "&" . a:op)')
  for wn in wd
    call win_execute(wn, 'let [tl, bl] = [line("w0"), line("w$")]')
    let se = getwinvar(wn, s:wpf.tl)
    if !empty(se) | let uc += (tl < se.sl || se.el < bl) | endif
    if has_key(v:event, wn) | let uc += (v:event[wn].width != 0) | endif
  endfor
  if 0 < uc
    call s:VirtLineDel(wd, 0)
    call s:VirtLineAdd(wd, a:op)
  endif
endfunction

function! s:VLAdd(wn, op, ln, ab) abort
  let bn = winbufnr(a:wn)
  if has('nvim')
    call nvim_buf_set_extmark(bn, s:wpf.ns, a:ln - 1, 0,
                  \{'virt_lines': [[[s:wpf.ht[a:op][1], s:wpf.ht[a:op][0]]]],
                                \'virt_lines_above': a:ab ? v:true : v:false})
  else
    " in current vim, prop_add() does not work well with 'text_wrap:truncate'
    " so truncate text here as a work around
    "call prop_add(a:ln, 0, {'type': s:wpf.tl . '_' . a:op, 'bufnr': bn,
          "\'text': s:wpf.ht[a:op][1], 'text_align': a:ab ? 'above': 'below'})
    let wi = getwininfo((a:wn))[0]
    let tc = wi.width - wi.textoff - (getwinvar(a:wn, '&list') ? 2 : 1)
    call prop_add(a:ln, 0, {'type': s:wpf.tl . '_' . a:op, 'bufnr': bn,
                                            \'text': s:wpf.ht[a:op][1][: tc],
                                      \'text_align': a:ab ? 'above': 'below'})
  endif
endfunction

function! s:VLDel(wn) abort
  let bn = winbufnr(a:wn)
  if has('nvim')
    for id in nvim_buf_get_extmarks(bn, s:wpf.ns, 0, -1, {})
      call nvim_buf_del_extmark(bn, s:wpf.ns, id[0])
    endfor
  else
    for tn in keys(s:wpf.ht)
      let tn = s:wpf.tl . '_' . tn
      if !empty(prop_find({'type': tn, 'bufnr': bn, 'lnum': 1, 'col': 1}))
        call prop_remove({'type': tn, 'bufnr': bn, 'all': 1})
      endif
    endfor
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
