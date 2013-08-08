let s:exists = {}
function! livestyle#lang#exists(type)
  if len(a:type) == 0
    return 0
  elseif has_key(s:exists, a:type)
    return s:exists[a:type]
  endif
  let s:exists[a:type] = len(globpath(&rtp, 'autoload/livestyle/lang/'.a:type.'.vim')) > 0
  return s:exists[a:type]
endfunction

