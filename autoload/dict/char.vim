" 汉字卡片: char 表(base+detail+related 合并行) → 渲染

let s:structs = {
      \ 'D0': '独体', 'D1': '独体(镶嵌)',
      \ 'A0': '品字形',
      \ 'B0': '上下', 'B1': '上下(相等)', 'B2': '上下(上小下大)', 'B3': '上下(上大下小)', 'B4': '上下(田字)',
      \ 'E0': '上中下', 'E1': '上中下(相等)', 'E2': '上中下(不等)',
      \ 'H0': '左右', 'H1': '左右(相等)', 'H2': '左右(左窄右宽)', 'H3': '左右(左宽右窄)',
      \ 'M0': '左中右', 'M1': '左中右(相等)', 'M2': '左中右(不等)',
      \ 'Q0': '全包围', 'R0': '半包围', 'R1': '半包围(左包右)', 'R2': '半包围(左上包右下)',
      \ 'R3': '半包围(右上包左下)', 'R4': '半包围(左下包右上)', 'R5': '半包围(上包下)', 'R6': '半包围(下包上)'}

function! dict#char#show(ch) abort
  let row = dict#db#char(a:ch)
  let mapped = ''
  if empty(row)
    " 未命中: 繁体 → 简体映射后重查
    let simp = dict#db#variant_simp(a:ch)
    if simp !=# ''
      let mapped = simp
      let row = dict#db#char(mapped)
    endif
  endif
  if empty(row)
    call dict#util#notify('未收录「' . a:ch . '」')
    return
  endif
  call dict#view#show(s:format(mapped ==# '' ? a:ch : mapped, row))
endfunction

function! s:format(ch, row) abort
  let lines = []
  let base    = dict#util#json_dict(a:row, 'base')
  let detail  = dict#util#json_dict(a:row, 'detail')
  let related = dict#util#json_dict(a:row, 'related')

  " 标题行: 字 拼音
  let prons = dict#util#dlist(detail, 'pronunciations')
  let pins = []
  for pron in prons
    let p = dict#util#dstr(pron, 'pinyin')
    if p !=# '' && index(pins, p) < 0
      call add(pins, p)
    endif
  endfor
  if empty(pins)
    for p in dict#util#dlist(base, 'pinyin')
      if type(p) == type('') && p !=# '' && index(pins, p) < 0
        call add(pins, p)
      endif
    endfor
  endif
  call add(lines, a:ch . (empty(pins) ? '' : '   ' . dict#util#join(pins, ' / ')))

  " 属性行: 部首 · 笔画 · 结构 · 常用度
  let attr = []
  let rad = dict#util#dstr(base, 'radicals')
  if rad !=# ''
    call add(attr, '部首 ' . rad)
  endif
  let strokes = dict#util#dnum(base, 'strokes', -1)
  if strokes > 0
    call add(attr, strokes . ' 画')
  endif
  let st = dict#util#dstr(base, 'structure')
  if has_key(s:structs, st)
    call add(attr, s:structs[st])
  endif
  let fl = s:freq_label(dict#util#dnum(base, 'frequency', -1))
  if fl !=# ''
    call add(attr, fl)
  endif
  if !empty(attr)
    call add(lines, join(attr, ' · '))
  endif
  let extra = []
  let trad = dict#util#dstr(base, 'traditional')
  if trad !=# ''
    call add(extra, '繁 ' . trad)
  endif
  let vari = dict#util#dstr(base, 'variant')
  if vari !=# ''
    call add(extra, '异 ' . vari)
  endif
  if !empty(extra)
    call add(lines, join(extra, '  ·  '))
  endif
  call add(lines, repeat('─', 32))

  " 释义: 按读音分组
  if empty(prons)
    call add(lines, '(未收录详细释义)')
  else
    for pron in prons
      let pinyin = dict#util#dstr(pron, 'pinyin')
      call add(lines, '【' . (pinyin !=# '' ? pinyin : '?') . '】')
      let expls = dict#util#dlist(pron, 'explanations')
      if empty(expls)
        call add(lines, '  (暂无释义)')
        continue
      endif
      let shown = 0
      for ex in expls
        let content = dict#util#dstr(ex, 'content')
        if content ==# ''
          if type(ex) == type({}) && get(ex, 'unknown', 0) == 1
            let content = '义未详。'
          else
            continue
          endif
        endif
        let shown += 1
        let speech = dict#util#dstr(ex, 'speech')
        let head = speech !=# '' ? '(' . speech . ') ' : ''
        call add(lines, '  ' . shown . '. ' . head . content)
        for d in dict#util#dlist(ex, 'detail')
          let cite = dict#util#cite(d)
          if cite !=# ''
            call add(lines, '      · ' . cite)
          endif
        endfor
        let example = dict#util#dstr(ex, 'example')
        if example !=# ''
          call add(lines, '      例: ' . example)
        endif
        for w in dict#util#dlist(ex, 'words')
          let word = dict#util#dstr(w, 'word')
          if word !=# ''
            let wt = dict#util#dstr(w, 'text')
            call add(lines, '      ◇ ' . word . (wt !=# '' ? ': ' . wt : ''))
          endif
        endfor
        for [k, tag] in [['same', '通'], ['refer', '参'], ['modern', '今']]
          let v = dict#util#dstr(ex, k)
          if v !=# ''
            call add(lines, '      ' . tag . ': ' . v)
          endif
        endfor
      endfor
      if shown == 0
        call add(lines, '  (暂无释义)')
      endif
    endfor
  endif

  " 近义 / 反义 / 形近
  let parts = []
  for [k, tag] in [['synonyms', '近义'], ['antonyms', '反义'], ['likeness', '形近']]
    let j = dict#util#join(dict#util#dlist(related, k), ' · ')
    if j !=# ''
      call add(parts, tag . ': ' . j)
    endif
  endfor
  if !empty(parts)
    call add(lines, repeat('─', 32))
    call extend(lines, parts)
  endif
  return lines
endfunction

function! s:freq_label(n) abort
  let labels = ['最常用', '较常用', '次常用', '二级字', '三级字', '生僻']
  if type(a:n) != type(0) || a:n < 0
    return ''
  endif
  return a:n < len(labels) ? labels[a:n] : '生僻'
endfunction
