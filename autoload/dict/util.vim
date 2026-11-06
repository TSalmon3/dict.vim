function! dict#util#notify(msg) abort"{{{
  echohl WarningMsg
  echomsg 'Dict: ' . a:msg
  echohl None
endfunction"}}}

" 按字符数截断
function! dict#util#clip(s, n) abort
  if strchars(a:s) <= a:n
    return a:s
  endif
  return strcharpart(a:s, 0, a:n) . '…'
endfunction

function! dict#util#iscjk(ch) abort
  if strchars(a:ch) != 1
    return 0
  endif
  let n = char2nr(a:ch)
  return (n >= 0x3400 && n <= 0x9FFF)
        \ || (n >= 0xF900 && n <= 0xFAFF)
        \ || (n >= 0x20000 && n <= 0x3FFFF)
endfunction

function! dict#util#dstr(d, k) abort"{{{
  if type(a:d) != type({}) || !has_key(a:d, a:k)
    return ''
  endif
  let v = a:d[a:k]
  return type(v) == type('') ? v : ''
endfunction"}}}

function! dict#util#dnum(d, k, default) abort"{{{
  if type(a:d) != type({}) || !has_key(a:d, a:k)
    return a:default
  endif
  let v = a:d[a:k]
  return type(v) == type(0) ? v : a:default
endfunction"}}}

function! dict#util#dlist(d, k) abort"{{{
  if type(a:d) != type({}) || !has_key(a:d, a:k)
    return []
  endif
  let v = a:d[a:k]
  return type(v) == type([]) ? v : []
endfunction"}}}

function! dict#util#json_dict(d, k) abort"{{{
  if type(a:d) != type({}) || !has_key(a:d, a:k)
    return {}
  endif
  let v = a:d[a:k]
  if type(v) != type('') || v ==# ''
    return {}
  endif
  try
    let parsed = json_decode(v)
  catch /^Vim\%((\a\+)\)\=:E\d\+:/
    " E491(Vim) / E474(Neovim): JSON 解析失败
    call dict#util#notify('字段 ' . a:k . ' JSON 解析失败: ' . v:exception)
    return {}
  endtry
  return type(parsed) == type({}) ? parsed : {}
endfunction"}}}

function! dict#util#cite(d) abort"{{{
  let text = dict#util#dstr(a:d, 'text')
  if text ==# ''
    return ''
  endif
  let book = dict#util#dstr(a:d, 'book')
  return text . (book !=# '' ? '  ——' . book : '')
endfunction"}}}

function! dict#util#join(v, sep) abort"{{{
  if type(a:v) != type([])
    return ''
  endif
  let parts = []
  for x in a:v
    if type(x) == type('')
      call add(parts, x)
    elseif type(x) == type(0)
      call add(parts, string(x))
    endif
  endfor
  return join(parts, a:sep)
endfunction"}}}
