" wrapfiller.vim: Align each wrapped line virtually between windows
"
" Last Change: 2025/07/27
" Version:     2.3
" Author:      Rick Howe (Takumi Ohtani) <rdcxy754@ybb.ne.jp>
" Copyright:   (c) 2023-2025 Rick Howe
" License:     MIT

let s:save_cpo = &cpoptions
set cpo&vim

let s:wf = {op -> 'wrapfiller_' . op}

let s:op = #{diff: #{ev: [['DiffUpdated', 'l']]},
            \list: #{ev: [['TextChanged', 'l'], ['InsertLeave', 'l']]}}
for op in keys(s:op)
  let s:op[op].ev += [['WinScrolled', 'g'], ['OptionSet', 'g']]
endfor

function! wrapfiller#WrapFiller(op, ...) abort
  let wd = gettabinfo(tabpagenr())[0].windows
  for op in keys(s:op) | call s:DelVirtLines(op, wd, a:0 ? a:1 : 1) | endfor
  if get(t:, 'WrapFiller', get(g:, 'WrapFiller', 1))
    for op in ['diff', 'list']
      let wx = filter(copy(wd), 'getwinvar(v:val, "&" . op)')
      if 1 < len(wx)
        call s:SetVirtLines(op)
        call s:AddVirtLines(op, wx)
        break
      endif
    endfor
  endif
  call s:SetEvent()
endfunction

function! s:SetVirtLines(op) abort
  let ht = #{diff: ['DiffDelete', (&fillchars =~ 'diff') ?
                                \matchstr(&fillchars, 'diff:\zs.') : '-', -1],
            \list: ['NonText', '<', 3],
            \0: ['EndOfBuffer', (&fillchars =~ 'eob') ?
                                  \matchstr(&fillchars, 'eob:\zs.') : '~', 1]}
  let vl = get(g:, 'WrapFillerType', 1)
  let [s:op[a:op].hl, s:op[a:op].ch, s:op[a:op].cn] =
      \(type(vl) == type([]) && len(vl) == 3) ? vl : ht[(vl == 0) ? vl : a:op]
  if has('nvim')
    let s:op[a:op].ns = nvim_create_namespace(s:wf(a:op))
  else
    call function(empty(prop_type_get(s:wf(a:op))) ? 'prop_type_add' :
                \'prop_type_change')(s:wf(a:op), #{highlight: s:op[a:op].hl})
  endif
endfunction

function! s:AddVirtLines(op, wd) abort
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
    " set first/last and top/bottom lines on each window
    let tb = {}
    for wn in a:wd
      let [fl, tl, bl, ll] = [1] + map(['w0', 'w$', '$'], 'line(v:val, wn)')
      if &diffopt !~ 'linematch'
        let wh = winheight(wn)
        let [tl, bl] = [max([tl - wh, fl]), min([bl + wh, ll])]
      endif
      while fl < tl
        call win_execute(wn, 'let eh = s:GetPureLines(tl - 1, tl - 1)')
        if !empty(eh) | let tl -= 1 | else | break | endif
      endwhile
      while bl < ll
        call win_execute(wn, 'let eh = s:GetPureLines(bl + 1, bl + 1)')
        if !empty(eh) | let bl += 1 | else | break | endif
      endwhile
      let se = getwinvar(wn, s:wf(a:op))
      let tb[wn] = #{fl: fl, tl: tl, bl: bl, ll: ll, sl: empty(se) ? 0 : se.sl}
    endfor
    " apply previous start line to fl/ll if tl is below/above it in all win
    let [tn, bn] = [0, 0]
    let sl = filter(map(filter(values(tb), '0 < v:val.sl'),
                                        \'v:val.tl - v:val.sl'), 'v:val != 0')
    for wn in a:wd
      if 0 < tb[wn].sl
        if 0 < min(sl) | let tb[wn].fl = tb[wn].sl
        elseif max(sl) < 0 | let tb[wn].ll = tb[wn].sl
        endif
      endif
      let [tn, bn] += [tb[wn].tl - tb[wn].fl, tb[wn].ll - tb[wn].tl]
    endfor
    " find a corresponding base start line between windows
    if tn <= bn
      for wn in a:wd
        call win_execute(wn, 'let eh = s:GetPureLines(tb[wn].fl, tb[wn].tl)')
        let tb[wn].eh = eh | let tb[wn].en = len(eh)
      endfor
      let ex = min(map(values(tb), 'v:val.en'))
      let zz.sx = (ex == 0)
      for wn in a:wd
        let zz[wn].sl = (0 < ex) ? tb[wn].eh[ex - 1] : tb[wn].fl
        let zz[wn].el = tb[wn].bl
      endfor
    else
      let ex = 1
      for wn in a:wd
        call win_execute(wn, 'let eh = s:GetPureLines(tb[wn].tl, tb[wn].ll)')
        let tb[wn].eh = eh | let tb[wn].en = len(eh)
        if 0 < tb[wn].en && tb[wn].eh[0] == tb[wn].tl | let ex = 0 | endif
      endfor
      let ex += max(map(values(tb), 'v:val.en'))
      let zz.sx = 0
      for wn in a:wd
        let tl = tb[wn].tl
        let rc = ex - tb[wn].en
        while 0 < rc
          let tl -= rc
          call win_execute(wn, 'let eh = (tl < tb[wn].fl) ?
                  \repeat([tb[wn].fl], rc) : s:GetPureLines(tl, tl + rc - 1)')
          let tb[wn].eh = eh + tb[wn].eh
          let rc -= len(eh)
        endwhile
        let [zz[wn].sl, zz.sx] = !empty(tb[wn].eh) ? [tb[wn].eh[0], zz.sx] :
                                                              \[tb[wn].fl, 1]
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
          call win_execute(wn, 'let rc = s:CountScreenRows(ln)')
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
      let [fl, tl, bl, ll] = [1] + map(['w0', 'w$', '$'], 'line(v:val, wn)')
      let wh = winheight(wn)
      let [tl, bl] = [max([tl - wh, fl]), min([bl + wh, ll])]
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
        call win_execute(wn, 'let rc = s:CountScreenRows(ln)')
        let lr[wn] += [[ln, rc]]
      endfor
    endfor
  endif
  " compare rows between windows and count required virtual lines
  let ml = get(t:, 'WrapFillerMinLines', get(g:, 'WrapFillerMinLines', 0))
  let vl = {} | for wn in a:wd | let vl[wn] = [] | endfor
  let ix = 0
  while 1
    let rn = {}
    for wn in a:wd
      if ix < len(lr[wn]) | let rn[wn] = lr[wn][ix][1] | endif
    endfor
    if len(rn) < 2 | break | endif
    let rx = max(values(rn)) + ml
    for wn in keys(rn)
      let rc = rx - rn[wn]
      if 0 < rc | let vl[wn] += [[lr[wn][ix][0], rc]] | endif
    endfor
    let ix += 1
  endwhile
  " draw virtual lines and set wrapfiller variable on each window
  for wn in a:wd
    let wi = getwininfo(wn)[0]
    if !empty(vl[wn])
      let cn = s:op[a:op].cn
      if cn < 0
        let cn = wi.width - wi.textoff
        if !has('nvim')
          let cn -= (getwinvar(wn, '&list') &&
                \getwinvar(wn, '&listchars') =~ 'eol')  " WA for a bug? in vim
        endif
      endif
      let [hl, tx] = [s:op[a:op].hl, repeat(s:op[a:op].ch, cn)]
      for [ln, rc] in vl[wn]
        while 0 < rc
          call s:AddVL(a:op, wn, abs(ln), hl, tx)
          let rc -= 1
        endwhile
      endfor
    endif
    call setwinvar(wn, s:wf(a:op), #{sl: zz[wn].sl, el: zz[wn].el,
                \ww: wi.width, wh: wi.height, tl: wi.topline, bl: wi.botline,
                                                              \to: wi.textoff,
              \rc: screenpos(wn, wi.botline, col([wi.botline, '$']) - 1).row})
  endfor
endfunction

function! s:GetPureLines(sl, el) abort
  return filter(range(a:sl, a:el),
                        \'diff_hlID(v:val, 1) == 0 && foldlevel(v:val) == 0')
endfunction

function! s:CountScreenRows(ln) abort
  let rc = 1
  if &wrap
    let wi = getwininfo(win_getid())[0]
    let vc = virtcol([a:ln, '$']) - 1 + (&list && &listchars =~ 'eol')
    let nw = (&cpoptions !~# 'n') ? 0 :
                          \&number ? max([len(line('$')) + 1, &numberwidth]) :
                                          \&relativenumber ? &numberwidth : 0
    let rc += (vc - 1 + nw) / (wi.width - wi.textoff + nw)
  endif
  return rc
endfunction

function! s:DelVirtLines(op, wd, cl) abort
  for wn in a:wd
    let wv = getwinvar(wn, '')
    if has_key(wv, s:wf(a:op))
      call s:DelVL(a:op, wn)
      if a:cl | unlet wv[s:wf(a:op)] | endif
    endif
  endfor
endfunction

function! s:SetEvent() abort
  for op in keys(s:op)
    let ac = []
    let ww = filter(getwininfo(), 'has_key(v:val.variables, s:wf(op))')
    if !empty(ww)
      for en in range(len(s:op[op].ev))
        let [ev, gl] = s:op[op].ev[en]
        if gl == 'l'
          for wi in ww
            let ac += [[ev, '<buffer=' . wi.bufnr . '>', en]]
          endfor
        else
          let ac += [[ev, '*', en]]
        endif
      endfor
      call map(ac, '"autocmd " . v:val[0] . " " . v:val[1] .
                  \" call s:UpdVirtLines(''" . op . "'', " . v:val[2] . ")"')
    endif
    let ac = ['augroup ' . s:wf(op), 'autocmd!'] + ac + ['augroup END'] +
                                  \(empty(ac) ? ['augroup! ' . s:wf(op)] : [])
    call execute(ac)
  endfor
endfunction

function! s:UpdVirtLines(op, en) abort
  let ev = s:op[a:op].ev[a:en][0]
  if ev == 'OptionSet'
    if v:option_old == v:option_new ||
            \(exists('v:option_command') && v:option_command == 'modeline') ||
      \index(['wrap', 'tabstop', 'vartabstop', 'listchars', 'cpoptions',
      \'linebreak', 'breakat', 'breakindent', 'breakindentopt', 'showbreak',
      \'number', 'relativenumber', 'numberwidth', 'foldcolumn', 'signcolumn',
                          \'display', 'ambiwidth'], expand('<amatch>')) == -1
      return
    endif
  endif
  let ud = 0
  for wn in gettabinfo(tabpagenr())[0].windows
    let se = getwinvar(wn, s:wf(a:op))
    if !empty(se)
      let wi = getwininfo(wn)[0]
      if ev == 'WinScrolled'
        let ud += (wi.topline < se.sl || se.el < wi.botline ||
                                    \[se.ww, se.wh] != [wi.width, wi.height])
      else
        let ud += ([se.tl, se.bl, se.to, se.rc] !=
                                        \[wi.topline, wi.botline, wi.textoff,
                  \screenpos(wn, wi.botline, col([wi.botline, '$']) - 1).row])
      endif
    endif
  endfor
  if 0 < ud
    call wrapfiller#WrapFiller(a:op,
                          \(ev == 'WinScrolled' || ev == 'OptionSet') ? 0 : 1)
  endif
endfunction

if has('nvim')
function! s:AddVL(op, wn, ln, hl, tx) abort
  let bn = winbufnr(a:wn)
  let [ln, ab] = (a:ln == 0) ? [1, v:true] : [a:ln, v:false]
  call nvim_buf_set_extmark(bn, s:op[a:op].ns, ln - 1, 0,
                      \#{virt_lines: [[[a:tx, a:hl]]], virt_lines_above: ab})
endfunction

function! s:DelVL(op, wn) abort
  let bn = winbufnr(a:wn)
  for id in nvim_buf_get_extmarks(bn, s:op[a:op].ns, 0, -1, {})
    call nvim_buf_del_extmark(bn, s:op[a:op].ns, id[0])
  endfor
endfunction
else
function! s:AddVL(op, wn, ln, hl, tx) abort
  let bn = winbufnr(a:wn)
  let [ln, ab] = (a:ln == 0) ? [1, 'above'] : [a:ln, 'below']
  call prop_add(ln, 0, #{type: s:wf(a:op), bufnr: bn, text: a:tx,
                                                            \text_align: ab})
endfunction

function! s:DelVL(op, wn) abort
  let bn = winbufnr(a:wn)
  if !empty(prop_find(#{type: s:wf(a:op), bufnr: bn, lnum: 1, col: 1}))
    call prop_remove(#{type: s:wf(a:op), bufnr: bn, all: 1})
  endif
endfunction
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=0 sts=-1 et
