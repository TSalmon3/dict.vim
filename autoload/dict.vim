function! dict#cmd(args) abort"{{{
  if trim(a:args) ==# ''
    call dict#util#notify('用法: :Dict 反 | :Dict 一帆风顺 | :Dict hello')
    return
  endif
  return dict#lookup(a:args)
endfunction"}}}

function! dict#lookup(text) abort"{{{
  return s:lookup(a:text, 1)
endfunction"}}}

function! dict#back() abort"{{{
  let text = dict#hist#back()
  if text ==# ''
    call dict#util#notify('没有可返回的查询')
    return
  endif
  call s:lookup(text, 0)
endfunction"}}}

function! dict#forward() abort"{{{
  let text = dict#hist#forward()
  if text ==# ''
    call dict#util#notify('没有可前进的查询')
    return
  endif
  call s:lookup(text, 0)
endfunction"}}}

function! dict#lookup_at_cursor() abort"{{{
  if line('.') <= get(b:, 'dict_help_height', 0)
    return
  endif
  let F = get(g:, 'dict_cword_func', '')
  if type(F) == type(function('tr')) || (type(F) == type('') && F !=# '')
    try
      let t = call(F, [])
    catch
      call dict#util#notify('g:dict_cword_func(' . string(F) . ') 调用失败: ' . v:exception)
      return
    endtry
  else
    let t = dict#view#cursor_text()
  endif
  if type(t) != type('') || t ==# ''
    call dict#util#notify('光标下没有可查询的汉字/词/英文')
    return
  endif
  call dict#lookup(t)
endfunction"}}}

function! dict#lookup_visual() abort"{{{
  let saved = [getpos('.'), &selection, getreg('"'), getregtype('"')]
  set selection=inclusive
  try
    silent normal! gvy
    let raw = getreg('"')
  finally
    call setpos('.', saved[0])
    let &selection = saved[1]
    call setreg('"', saved[2], saved[3])
  endtry
  let lines = filter(map(split(raw, "\n", 1), 'trim(v:val)'), 'v:val !=# ""')
  if empty(lines)
    return
  endif
  let text = s:is_word_en(join(lines, '')) ? join(lines, ' ') : join(lines, '')
  call dict#lookup(text)
endfunction"}}}

function! s:lookup(text, record) abort"{{{
  if &encoding !=# 'utf-8'
    call dict#util#notify('需要 set encoding=utf-8 (当前: ' . &encoding . ')')
    return
  endif
  let text = trim(a:text)
  if text ==# ''
    return
  endif
  let chars = split(text, '\zs')
  if len(chars) == 1 && dict#util#iscjk(chars[0])
    let kind = 'char'
  elseif s:has_cjk(chars) && text !~# '\s'
    let kind = 'word'
  elseif s:is_word_en(text)
    let kind = 'word_en'
  else
    call dict#util#notify('不支持的输入「' . dict#util#clip(text, 40) . '」(单个汉字 / 中文词 / 英文单词)')
    return
  endif
  if !dict#db#ready()
    return
  endif
  if a:record
    call dict#hist#add(text)
  endif
  if kind ==# 'char'
    call dict#char#show(chars[0])
  elseif kind ==# 'word'
    call dict#word#show(text)
  else
    call dict#word_en#show(text)
  endif
endfunction"}}}

function! s:is_word_en(text) abort"{{{
  if a:text !~# '[A-Za-z]' || a:text =~# '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'
    return 0
  endif
  for c in split(a:text, '\zs')
    if dict#util#iscjk(c)
      return 0
    endif
  endfor
  return 1
endfunction"}}}

function! s:has_cjk(chars) abort"{{{
  for c in a:chars
    if dict#util#iscjk(c)
      return 1
    endif
  endfor
  return 0
endfunction"}}}
