" 词语/成语: word 表精确命中出卡片, 未命中出前缀候选

function! dict#word#show(word) abort
  let row = dict#db#word(a:word)
  if !empty(row)
    call dict#view#show(s:format_entry(a:word, dict#util#json_dict(row, 'entry')))
    return
  endif
  " 前缀候选
  let rows = dict#db#word_prefix(a:word)
  if empty(rows)
    call dict#util#notify('未收录「' . a:word . '」')
    return
  endif
  let lines = []
  for r in rows
    call add(lines, '  ' . s:cand_line(r))
  endfor
  call dict#view#candidates(a:word, rows, lines)
endfunction

function! s:cand_line(r) abort
  let l = dict#util#dstr(a:r, 'word')
  if l ==# ''
    return ''
  endif
  let p = dict#util#dstr(a:r, 'pinyin')
  if p !=# ''
    let l .= '   ' . p
  endif
  let e = dict#util#dstr(a:r, 'explanation')
  if e !=# ''
    let l .= '   ' . dict#util#clip(e, 36)
  endif
  return l
endfunction

function! s:format_entry(word, e) abort
  let lines = []
  let p = dict#util#dstr(a:e, 'pinyin')
  call add(lines, a:word . (p !=# '' ? '   ' . p : ''))
  call add(lines, repeat('─', 32))
  let expl = dict#util#dstr(a:e, 'explanation')
  call add(lines, '【释义】' . (expl !=# '' ? expl : '暂无释义'))
  for [k, label] in [['source', '出处'], ['quote', '书证'], ['example', '例句'], ['usage', '用法'], ['notice', '注意']]
    let v = get(a:e, k, '')
    if type(v) == type({})
      let cite = dict#util#cite(v)
      if cite !=# ''
        call add(lines, '【' . label . '】' . cite)
      endif
    elseif type(v) == type('') && v !=# ''
      call add(lines, '【' . label . '】' . v)
    endif
  endfor
  for [k, label] in [['similar', '近义'], ['opposite', '反义']]
    let j = dict#util#join(dict#util#dlist(a:e, k), ' · ')
    if j !=# ''
      call add(lines, '【' . label . '】' . j)
    endif
  endfor
  let story = dict#util#dlist(a:e, 'story')
  if !empty(story)
    let i = 0
    for para in story
      if type(para) != type('') || para ==# ''
        continue
      endif
      call add(lines, (i == 0 ? '【典故】' : '        ') . para)
      let i += 1
    endfor
  endif
  return lines
endfunction
