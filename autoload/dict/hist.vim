let s:items = []
let s:idx   = -1

function! s:limit() abort
  let n = dict#config#get('dict_history_max')
  return type(n) == type(0) && n > 0 ? n : dict#config#default('dict_history_max')
endfunction

function! dict#hist#add(text) abort
  if a:text ==# ''
    return
  endif
  if s:idx >= 0 && s:items[s:idx] ==# a:text
    return
  endif
  if s:idx < len(s:items) - 1
    call remove(s:items, s:idx + 1, -1)
  endif
  call add(s:items, a:text)
  let s:idx = len(s:items) - 1
  let max = s:limit()
  if len(s:items) > max
    let drop = len(s:items) - max
    call remove(s:items, 0, drop - 1)
    let s:idx -= drop
  endif
endfunction

function! dict#hist#back() abort
  if s:idx <= 0
    return ''
  endif
  let s:idx -= 1
  return s:items[s:idx]
endfunction

function! dict#hist#forward() abort
  if s:idx < 0 || s:idx >= len(s:items) - 1
    return ''
  endif
  let s:idx += 1
  return s:items[s:idx]
endfunction
