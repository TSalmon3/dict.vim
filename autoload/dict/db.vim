let s:checked = 0
let s:reason  = ''

function! dict#db#db_path() abort"{{{
  return expand(dict#config#get('dict_db_path'))
endfunction"}}}

function! s:quote(s) abort"{{{
  return "'" . substitute(a:s, "'", "''", 'g') . "'"
endfunction"}}}

function! s:like_prefix(s) abort"{{{
  return escape(escape(a:s, '\'), '%_') . '%'
endfunction"}}}

function! s:check() abort"{{{
  if !s:checked
    let s:checked = 1
    if !executable('sqlite3')
      let s:reason = '缺少 sqlite3 CLI'
    else
      let m = matchlist(system(['sqlite3', '--version']), '\v^(\d+)\.(\d+)')
      if empty(m) || str2nr(m[1]) < 3
            \ || (str2nr(m[1]) == 3 && str2nr(m[2]) < 33)
        let s:reason = '需要 sqlite3 >= 3.33'
      endif
    endif
  endif
  return s:reason
endfunction"}}}

function! dict#db#ready() abort"{{{
  if !filereadable(dict#db#db_path())
    call dict#util#notify('数据库不存在(先 :DictInit)')
    return 0
  endif
  let reason = s:check()
  if reason !=# ''
    call dict#util#notify(reason)
    return 0
  endif
  return 1
endfunction"}}}

function! s:ok() abort"{{{
  return filereadable(dict#db#db_path()) && s:check() ==# ''
endfunction"}}}

function! s:query(sql) abort"{{{
  if !s:ok()
    return []
  endif
  let out = system(['sqlite3', '-batch', '-json', dict#db#db_path(), a:sql])
  if v:shell_error || out ==# ''
    return []
  endif
  try
    let rows = json_decode(out)
  catch /^Vim\%((\a\+)\)\=:E\d\+:/
    " E491(Vim) / E474(Neovim): sqlite3 -json 输出解析失败
    call dict#util#notify('查询结果 JSON 解析失败: ' . v:exception)
    return []
  endtry
  return type(rows) == type([]) ? rows : []
endfunction"}}}

function! dict#db#char(ch) abort"{{{
  let rows = s:query('SELECT base, detail, related FROM char WHERE char = ' . s:quote(a:ch))
  return empty(rows) ? {} : rows[0]
endfunction"}}}

function! dict#db#variant_simp(trad) abort"{{{
  let rows = s:query('SELECT simp FROM variant WHERE trad = ' . s:quote(a:trad))
  return empty(rows) ? '' : dict#util#dstr(rows[0], 'simp')
endfunction"}}}

function! dict#db#word(word) abort"{{{
  let rows = s:query('SELECT entry FROM word WHERE word = ' . s:quote(a:word))
  return empty(rows) ? {} : rows[0]
endfunction"}}}

function! dict#db#word_prefix(prefix) abort"{{{
  return s:query("SELECT word, pinyin, explanation FROM word WHERE word LIKE "
        \ . s:quote(s:like_prefix(a:prefix)) . " ESCAPE '\\' ORDER BY word LIMIT 201")
endfunction"}}}

function! dict#db#word_en(word) abort"{{{
  let rows = s:query('SELECT word, phonetic, definition, translation, collins, oxford, tag, bnc, frq, exchange FROM word_en WHERE word = '
        \ . s:quote(a:word) . ' LIMIT 1')
  return empty(rows) ? {} : rows[0]
endfunction"}}}

function! dict#db#word_en_prefix(prefix) abort"{{{
  return s:query("SELECT word, phonetic, substr(translation, 1, 200) AS translation FROM word_en WHERE word LIKE "
        \ . s:quote(s:like_prefix(a:prefix))
        \ . " ESCAPE '\\' ORDER BY COALESCE(NULLIF(CAST(frq AS INTEGER), 0), 999999999), word LIMIT 201")
endfunction"}}}
