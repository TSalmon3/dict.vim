" 英文词典: word_en 表(ECDICT), 精确命中出卡片, 未命中出前缀候选

let s:tag_labels = {
      \ 'zk': '中考', 'gk': '高考', 'cet4': '四级', 'cet6': '六级',
      \ 'ky': '考研', 'ielts': '雅思', 'toefl': '托福', 'gre': 'GRE',
      \ }

let s:exchange_labels = {
      \ 'p': '过去式', 'd': '过去分词', 'i': '现在分词',
      \ '3': '第三人称单数', 's': '复数', 'r': '比较级', 't': '最高级',
      \ '0': '原型', 'f': '复数',
      \ }

function! dict#word_en#show(text) abort
  let r = dict#db#word_en(a:text)
  if !empty(r)
    let title = dict#util#dstr(r, 'word')
    if title ==# ''
      let title = a:text
    endif
    call dict#view#show(s:format(title, r))
    return 1
  endif
  " 前缀候选
  let rows = dict#db#word_en_prefix(a:text)
  if empty(rows)
    call dict#util#notify('英文词典未收录「' . a:text . '」')
    return 0
  endif
  let lines = []
  for r in rows
    call add(lines, '  ' . s:cand_line(r))
  endfor
  call dict#view#candidates(a:text, rows, lines)
  return 1
endfunction

function! s:format(word, r) abort
  let lines = []
  let ph = dict#util#dstr(a:r, 'phonetic')
  call add(lines, a:word . (ph !=# '' ? '   ' . ph : ''))
  call add(lines, repeat('─', 32))

  let tr = dict#util#dstr(a:r, 'translation')
  if tr !=# ''
    call s:add_block(lines, '【释义】', tr)
  endif
  let df = dict#util#dstr(a:r, 'definition')
  if df !=# ''
    call s:add_block(lines, '【英英】', df)
  endif

  let ex = s:format_exchange(dict#util#dstr(a:r, 'exchange'))
  if ex !=# ''
    call add(lines, '【词形】' . ex)
  endif

  let meta = []
  for t in split(dict#util#dstr(a:r, 'tag'))
    call add(meta, get(s:tag_labels, t, t))
  endfor
  let collins = str2nr(dict#util#dstr(a:r, 'collins'))
  if collins > 0
    call add(meta, '柯林斯 ' . repeat('★', collins) . repeat('☆', max([0, 5 - collins])))
  endif
  if dict#util#dstr(a:r, 'oxford') ==# '1'
    call add(meta, '牛津 3000')
  endif
  let bnc = str2nr(dict#util#dstr(a:r, 'bnc'))
  if bnc > 0
    call add(meta, 'BNC ' . bnc)
  endif
  let frq = str2nr(dict#util#dstr(a:r, 'frq'))
  if frq > 0
    call add(meta, 'COCA ' . frq)
  endif
  if !empty(meta)
    call add(lines, '【标签】' . join(meta, ' · '))
  endif
  return lines
endfunction

function! s:add_block(lines, label, text) abort
  let parts = split(a:text, "\n", 1)
  while !empty(parts) && trim(parts[-1]) ==# ''
    call remove(parts, -1)
  endwhile
  if empty(parts)
    return
  endif
  let indent = repeat(' ', strdisplaywidth(a:label))
  call add(a:lines, a:label . substitute(parts[0], '^\s\+', '', ''))
  for p in parts[1:]
    call add(a:lines, p ==# '' ? '' : indent . substitute(p, '^\s\+', '', ''))
  endfor
endfunction

function! s:format_exchange(ex) abort
  let parts = []
  for item in split(a:ex, '/')
    let m = matchlist(item, '^\([^:]*\):\(.*\)$')
    if empty(m) || m[2] ==# ''
      continue
    endif
    if m[1] ==# '1'
      " 1 的值是词形类型串(如 s / dp / s3), 不是单词
      let types = []
      for c in split(m[2], '\zs')
        call add(types, get(s:exchange_labels, c, c))
      endfor
      call add(parts, '类别 ' . join(types, '/'))
    else
      let label = get(s:exchange_labels, m[1], m[1])
      call add(parts, label . ' ' . m[2])
    endif
  endfor
  return join(parts, ' · ')
endfunction

function! s:cand_line(r) abort
  let line = dict#util#dstr(a:r, 'word')
  let ph = dict#util#dstr(a:r, 'phonetic')
  if ph !=# ''
    let line .= '   ' . ph
  endif
  let tr = dict#util#dstr(a:r, 'translation')
  if tr !=# ''
    let first = substitute(get(split(tr, "\n"), 0, ''), '^\s\+', '', '')
    if first !=# ''
      let line .= '   ' . dict#util#clip(first, 36)
    endif
  endif
  return line
endfunction
