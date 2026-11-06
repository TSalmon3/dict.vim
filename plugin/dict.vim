if exists('g:loaded_dict')
  finish
endif
let g:loaded_dict = 1

call dict#config#setup()

command! -bar -bang -nargs=? -complete=dir DictInit call dict#init#run(<q-args>, <bang>0)
command! -bar -nargs=* Dict call dict#cmd(<q-args>)

nnoremap <silent> <Plug>(dict-lookup) :<C-u>call dict#lookup_at_cursor()<CR>
xnoremap <silent> <Plug>(dict-word)   :<C-u>call dict#lookup_visual()<CR>
