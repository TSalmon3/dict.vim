let s:bufname = 'dict://dict'
let s:default_keymaps = {
      \ 'lookup':  '<CR>',
      \ 'back':    '<C-o>',
      \ 'forward': '<C-i>',
      \ 'help':    '?',
      \ 'close':   'q',
      \ }

function! dict#view#show(lines, ...) abort"{{{
  if empty(a:lines)
    return
  endif
  let win = bufwinnr('^' . s:bufname . '$')
  if win > 0
    execute win . 'wincmd w'
  else
    let w = dict#config#get('dict_split_width')
    execute 'vertical' . (w > 0 ? ' ' . w : '') . ' split ' . fnameescape(s:bufname)
  endif
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal nomodifiable nospell nonumber norelativenumber
  silent! setlocal signcolumn=no foldcolumn=0 linebreak
  let b:dict_content = a:lines
  let b:dict_queries = a:0 && type(a:1) == type({}) ? a:1 : {}
  call s:render()
  setlocal wrap
  setlocal filetype=dict syntax=dict
  call s:map()
  call cursor(get(b:, 'dict_help_height', 0) + 1, 1)
endfunction"}}}

function! dict#view#candidates(prefix, rows, lines) abort"{{{
  if empty(a:rows)
    return
  endif
  let more = len(a:rows) > 200
  let rows = more ? a:rows[0:199] : a:rows
  let lines = more ? a:lines[0:199] : a:lines
  let n = more ? '200+' : len(rows)
  let heading = ['含「' . a:prefix . '」的词条 ' . n . ' 条, 光标 <CR> 逐条查看:', '']
  let queries = {}
  for i in range(len(rows))
    let word = dict#util#dstr(rows[i], 'word')
    if word !=# ''
      let queries[lines[i]] = word
    endif
  endfor
  call dict#view#show(heading + lines, queries)
endfunction"}}}

function! s:keymaps() abort"{{{
  let user = get(g:, 'dict_keymaps', {})
  return extend(copy(s:default_keymaps), type(user) == type({}) ? user : {})
endfunction"}}}

function! s:help_lines(keys) abort"{{{
  let lines = []
  for [name, desc] in [
        \ ['lookup',  '查光标字词'],
        \ ['back',    '后退'],
        \ ['forward', '前进'],
        \ ['close',   '关闭'],
        \ ['help',    '隐藏帮助'],
        \ ]
    let key = get(a:keys, name, '')
    if key !=# ''
      call add(lines, printf('" %-7s %s', key, desc))
    endif
  endfor
  return lines
endfunction"}}}

function! s:render() abort"{{{
  let keys = s:keymaps()
  let help = get(b:, 'dict_help', 0) && get(keys, 'help', '') !=# ''
  let b:dict_help = help
  let lines = get(b:, 'dict_content', [])
  let b:dict_help_height = 0
  if help
    let header = s:help_lines(keys)
    let b:dict_help_height = len(header)
    let lines = header + lines
  endif
  setlocal modifiable
  silent! execute '%delete _'
  call setline(1, lines)
  setlocal nomodifiable
endfunction"}}}

function! dict#view#toggle_help() abort"{{{
  if !exists('b:dict_content')
    return
  endif
  let rel = max([1, line('.') - get(b:, 'dict_help_height', 0)])
  let b:dict_help = !get(b:, 'dict_help', 0)
  call s:render()
  call cursor(min([line('$'), rel + get(b:, 'dict_help_height', 0)]), 1)
endfunction"}}}

function! dict#view#cursor_text() abort"{{{
  let queries = get(b:, 'dict_queries', {})
  if type(queries) == type({})
    let q = get(queries, getline('.'), '')
    if type(q) == type('') && q !=# ''
      return q
    endif
  endif
  let line = getline('.')
  if line ==# ''
    return ''
  endif
  let chars = split(line, '\zs')
  let idx = strchars(strpart(line, 0, col('.') - 1))
  if idx >= len(chars)
    let idx = len(chars) - 1
  endif
  if dict#util#iscjk(chars[idx])
    let i0 = idx
    let i1 = idx
    while i0 > 0 && dict#util#iscjk(chars[i0 - 1]) | let i0 -= 1 | endwhile
    while i1 + 1 < len(chars) && dict#util#iscjk(chars[i1 + 1]) | let i1 += 1 | endwhile
    return join(chars[i0:i1], '')
  endif
  let w = expand('<cword>')
  return w =~# '^[A-Za-z]\+$' ? w : ''
endfunction"}}}

function! s:map() abort"{{{
  let keys = s:keymaps()
  if exists('b:dict_keymaps')
    for [name, old] in items(b:dict_keymaps)
      if old !=# get(keys, name, '') && old !=# ''
        execute 'silent! nunmap <buffer> ' . old
      endif
    endfor
  endif
  let b:dict_keymaps = keys
  for [name, rhs] in [
        \ ['lookup',  'call dict#lookup_at_cursor()<CR>'],
        \ ['back',    'call dict#back()<CR>'],
        \ ['forward', 'call dict#forward()<CR>'],
        \ ['close',   'if winnr(''$'') > 1 <Bar> close <Bar> else <Bar> enew <Bar> endif<CR>'],
        \ ['help',    'call dict#view#toggle_help()<CR>'],
        \ ]
    let lhs = get(keys, name, '')
    if lhs !=# ''
      execute 'nnoremap <buffer><silent> ' . lhs . ' :<C-u>' . rhs
    endif
  endfor
endfunction"}}}
