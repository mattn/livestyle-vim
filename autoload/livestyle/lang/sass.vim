function! livestyle#lang#sass#init()
endfunction

function! livestyle#lang#sass#parse(buf)
  let buf = system('sass -s -C', a:buf)
  return livestyle#lang#css#parse(buf)
endfunction

function! livestyle#lang#sass#apply(patch)
  return livestyle#lang#css#apply(a:patch)
endfunction

function! livestyle#lang#sass#diff(css1, css2)
  return livestyle#lang#css#diff(a:css1, a:css2)
endfunction
