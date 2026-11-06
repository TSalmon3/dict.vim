" 数据导入: :DictInit

let s:plugin_root = fnamemodify(resolve(expand('<script>:p')), ':h:h:h')
let s:import_py   = s:plugin_root . '/python/dict_import.py'

function! dict#init#run(src, force) abort"{{{
  let src = trim(a:src)
  let explicit = src !=# ''
  if !explicit
    let src = dict#config#get('dict_data_dir')
  endif
  let src = fnamemodify(src, ':p')
  if src !~# '[/\\]$'
    let src .= '/'
  endif
  for f in ['character/char_base.json', 'character/char_detail.json',
        \ 'character/related.json', 'word/word.json', 'word_en/stardict.csv']
    if !filereadable(src . f)
      let hint = explicit ? '请检查数据目录'
            \ : '请设置 g:dict_data_dir 指向解压后的 dict/'
      call dict#util#notify('缺少 ' . src . f . ', ' . hint)
      return
    endif
  endfor
  if !executable('python3')
    call dict#util#notify('导入需要 python3')
    return
  endif
  let db = dict#db#db_path()
  let dir = fnamemodify(db, ':p:h')
  let mkdir_error = ''
  if !isdirectory(dir)
    try
      call mkdir(dir, 'p')
    catch /^Vim\%((\a\+)\)\=:E\d\+:/
      let mkdir_error = v:exception
    endtry
  endif
  if !isdirectory(dir)
    call dict#util#notify('无法创建目录: ' . dir
          \ . (mkdir_error !=# '' ? ' (' . mkdir_error . ')' : ''))
    return
  endif
  redraw
  echo 'Dict: 正在导入数据到 ' . db . ' (中文 + 英文, 约 20 秒)…'
  let args = ['python3', s:import_py, src, db]
  if a:force
    call add(args, '--force')
  endif
  let out = system(args)
  redraw!
  let lines = split(out, "\n")
  if v:shell_error
    call dict#util#notify('导入失败 — ' . join(lines[-3:], ' | '))
  else
    for ln in lines
      echomsg ln
    endfor
    echomsg 'Dict: 完成 → ' . db
  endif
endfunction"}}}
