let s:root = fnamemodify(resolve(expand('<sfile>:p')), ':h:h:h')

let s:defaults = {
      \ 'dict_data_dir':    s:root . '/dict',
      \ 'dict_db_path':     s:root . '/dict.db',
      \ 'dict_split_width': 50,
      \ 'dict_history_max': 50,
      \ }

function! dict#config#setup() abort
  for name in keys(s:defaults)
    if !exists('g:' . name)
      let g:{name} = s:defaults[name]
    endif
  endfor
endfunction

function! dict#config#get(name) abort
  return get(g:, a:name, dict#config#default(a:name))
endfunction

function! dict#config#default(name) abort
  return get(s:defaults, a:name, '')
endfunction
