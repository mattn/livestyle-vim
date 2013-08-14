function! livestyle#lang#scss#init()
endfunction

function! livestyle#lang#scss#parse(buf)
  let buf = system('scss -s -C', a:buf)
  return livestyle#lang#css#parse(buf)
endfunction

function! livestyle#lang#scss#apply(patch)
  return livestyle#lang#css#apply(a:patch)
endfunction

function! livestyle#lang#scss#diff(css1, css2)
  return livestyle#lang#css#diff(a:css1, a:css2)
endfunction
