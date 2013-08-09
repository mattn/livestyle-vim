if !exists('s:bufcache')
  let s:bufcache = {}
endif

let s:url = get(g:, 'livestyle_server_url', 'http://127.0.0.1:54000/')
let s:server = expand('<sfile>:p:h:h') . '/livestyled/livestyled'
if has('win32') || has('win64')
  let s:server = substitute(s:server, '/', '\\', 'g') . '.exe'
endif

if has('python')
  let s:use_python = 1
python <<EOF
import urllib, json, vim
EOF
else
  let s:use_python = 0
endif

function! s:files()
  return filter(map(filter(range(1, bufnr('$')), 'buflisted(v:val)'), 'fnamemodify(bufname(v:val), ":p:gs?\\?/?")'), 'filereadable(v:val)')
endfunction

function! livestyle#updateFiles()
  call s:do_post(s:url, {
  \  'action': 'updateFiles',
  \  'data': s:files(),
  \})
endfunction

function! s:json_decode(str)
  return webapi#json#decode(a:str)
endfunction

function! s:do_get(url)
  if s:use_python
python <<EOF
urllib.urlopen(vim.eval('a:url').read()
EOF
  else
    call webapi#http#get(a:url)
  endif
endfunction

function! s:do_post(url, params)
  if s:use_python
python <<EOF
urllib.urlopen(vim.eval('a:url'), json.dumps(vim.eval('a:params'), encoding=vim.eval('&encoding')).encode('utf-8')).read()
EOF
  else
    call webapi#http#post(a:url, webapi#json#encode(a:params))
  endif
endfunction

function! livestyle#update()
  let f = fnamemodify(bufname('%'), ':p:gs?\\?/?')
  if !livestyle#lang#exists(&ft)
    return
  endif
  let prev = has_key(s:bufcache, f) ? s:bufcache[f] : {}
  if !empty(prev) && prev['tick'] == b:changedtick
    return
  endif
  let buf = join(getline(1, '$'), "\n") . "\n"
  let cur = livestyle#lang#{&ft}#parse(buf)
  let patch = []
  if !empty(prev)
    let patch = livestyle#lang#{&ft}#diff(prev.data, cur)
  endif
  let s:bufcache[f] = {'tick': b:changedtick, 'data': cur}
  for p in patch
    if len(p) == 0
      continue
    endif
    call s:do_post(s:url, {
    \  'action': 'update',
    \  'data': {
    \    'editorFile': f,
    \    'patch': p,
    \  }
    \})
  endfor
endfunction

function! livestyle#shutdown()
  try
    call s:do_get(s:url . 'shutdown/')
  catch
  endtry
endfunction

function! s:find_vim()
  let e = filter(split($PATH, (has('win32')||has('win64')) ? ';' : ':'), 'executable(v:val . "/" . v:progname)')
  if len(e) > 0
    return e[0] . "/" . v:progname
  else
    return v:progname
  endif
endfunction

function! livestyle#reply(reply)
  try
    let pos = getpos('.')
    let res = webapi#json#decode(a:reply)
    if type(res) != 4 || !has_key(res, 'action') || res['action'] != 'update'
      return ''
    endif
    let f = res['data']['editorFile']
    let curwin = winnr()
    try
      for n in range(1, bufnr('$'))
        if fnamemodify(bufname(n), ":p") == f
          exe bufwinnr(n).'wincmd w'
          let patch = res['data']['patch']
          call livestyle#lang#{&ft}#apply(patch)
          break
        endif
      endfor
    finally
      exe curwin.'wincmd w'
    endtry
  catch
    echohl Error | echomsg v:exception "\n" . v:throwpoint | echohl None
  finally
    call setpos('.', pos)
    redraw
  endtry
  return ''
endfunction

function! livestyle#clear()
  let f = fnamemodify(bufname('%'), ':p:gs?\\?/?')
  if has_key(s:bufcache, f)
    call remove(s:bufcache, f)
  endif
endfunction

function! livestyle#open()
  if has('win32') || has('win64')
    exe printf('!start rundll32 url.dll,FileProtocolHandler %s', shellescape(expand('%:p')))
  elseif has('mac') || has('macunix') || has('gui_macvim') || system('uname') =~? '^darwin'
    exe printf('open %s', shellescape(expand('%:p')))
  elseif executable('xdg-open')
    exe printf('xdg-open %s', shellescape(expand('%:p')))
  elseif executable('firefox')
    exe printf('firefox %s &', shellescape(expand('%:p')))
  else
    echohl Error | echomsg "Can't find your browser" | echohl None
  endif
endfunction

function! livestyle#setup(...)
  if get(a:000, 0) != '!'
    if has('win32') || has('win64')
      if has('gui_running')
        silent exe '!start /min '.shellescape(s:server)
      else
        silent exe 'silent ! start /min '.s:server
      endif
    else
      silent exe '!'.shellescape(s:server).' > /dev/null 2>&1 > /dev/null &'
    endif
    redraw
    sleep 2
  endif
  let vimapp = printf('Vim%d.%d', v:version / 100, v:version % 100)
  call s:do_post(s:url . 'vim', {
  \  'name': v:servername,
  \  'path': s:find_vim(),
  \})
  call s:do_post(s:url, {
  \  'action': 'id',
  \  'data': {
  \    'id': vimapp,
  \    'title': vimapp,
  \    'icon': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAEnQAABJ0BfDRroQAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAMXSURBVDiNdZNbbFRVFIa/fTjTuRxnOi2EtJBo2kiiRiyEllEkamiqGAGjSTWRTMAoSELfIF4wrQJJVSyIQHzwQpCpOhSsGB80bXhAjcYATQuEsSUGaoFBalN75szM6czZe/tgOwWj+3X969//WvmW0FrzX08IYcSenrNdKl08fXxsp/4foYivW1v55JqnToQj4Wo0AgCt9fGepLqj+bcqlNDXeuf3PfHA+iqgDCBjZwqfJT/f1n30y4RZU1Mbf7SpaZGU6hbnyWKBrjPriNbkxcrlh+tjS2JMhzBNk9N9ZzqAhJFKXTj0xZHkmFIKz/PwPI+Rkd9JHPuQinkmZWaIk5c+4vof6VJ9aGiQk9//OARgdCWPTZw7N7Dedd2SIJVKMW/VWayID58IsnD2KiqilXiex+Xhy7z82rYLeSezGsAAUFIJpWTJQGmNzwzgM0Lc42yl6f5mCoUCV66M0L63leq64qX+/v4JAEMIYejoeKuUMyOgFaYIUDu+icaGZlx3knQ6zc69r7IwfpWHnq1+/MXWld1CCGEsWBrZeO+yufVKq1sSLJiMs2JJM/l8ntHRUdrff5365zPcVh7gL++iseKZu9bcWR9Za05m9VmZC7hKqqDneQDU3beIUGgZuVwO27Z5e18bsRdcguHgFCMG0rYcN6POG8Pn7Z9+/nbwoJQzOwgEAuRyOSbsCd7Z9wYPblCUV4QoM4P4fRZVstH+9L1vWkZ+zfQbAOWB6u/0TSM4joPjOOzav4OHXzKJVlqUzQriNy3mFh6xP+7obuk9OpAAMKfIY3qJQgiKXpGOA+00brIIV5ql2JFsg/1BR2dLT1dfYho4E0CjUUohpURrxZ4Du/VjmytEZPZMs5VZ7Ox/6/Ar6WEjeTOx/3CglBRCIKVH25vbr98Yv/bJ7f7leb9p4fdZhO2l7u62zoPpYT0I3F3XEJtf1xDzlxJks9lTPSd6//yq++vRMdveas4yvT07OvXmLc/FpVLq3V2HkmM35A+AmPpUAApA/PtKp5wtwHLd8VolhQxZ0atAFsgB+YFTv8hp/d+3KJyTs2tiKQAAAABJRU5ErkJggg==',
  \    'files': s:files(),
  \  }
  \})
  augroup LiveStyle
    autocmd!
    autocmd CursorHold * silent! call livestyle#update()
    autocmd CursorHoldI * silent! call livestyle#update()
    autocmd CursorMoved * silent! call livestyle#update()
    autocmd CursorMovedI * silent! call livestyle#update()
    autocmd InsertLeave * silent! call livestyle#update()
    autocmd BufEnter * silent! call livestyle#updateFiles()
    autocmd VimLeavePre * silent! call livestyle#shutdown()
  augroup END
  set updatetime=100
endfunction
