" dict:// 缓冲区语法高亮
if exists('b:current_syntax')
  finish
endif

syn match dictTitle   /\%1l[^"].*/
syn match dictHr      /^─\+$/
syn match dictHead    /【[^】]*】/
syn match dictAttr    /^\%(部首\|繁\|异\) .*/
syn match dictExample /^\s*· .*$/
syn match dictItem    /^\s*\%(◇\|例:\|通:\|参:\|今:\) .*$/
syn match dictHelp    /^".*$/

hi def link dictTitle   Title
hi def link dictHr      Comment
hi def link dictHead    Label
hi def link dictAttr    Comment
hi def link dictExample Comment
hi def link dictItem    Special
hi def link dictHelp    Comment

let b:current_syntax = 'dict'
