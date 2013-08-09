function! livestyle#lang#css#init()
endfunction

function! livestyle#lang#css#parse(buf)
  let buf = a:buf
  if len(buf) == 0
    let buf = join(getline(1, '$'), "\n") . "\n"
  endif
  let csss = split(buf, '[^{]\+{\([a-zA-Z0-9-_.:]\+\|:\|"[^"]*"\|''[^'']*''\|;\+\|\_\s\+\|/\*\_.\{-}\*/\)*}\zs\ze')
  let ret = {}
  for css in csss
    let t = split(css[:-2], '{')
    if len(t) != 2
      continue
    endif
    let k = substitute(t[0], '[ \t\r\n]\+', '', 'g')
    let k = substitute(k, '/\*\_.\{-}\*/', '', 'g')
    for p in split(t[1], ';')
      let pp = split(p, '^[^:]\+\zs:\ze.*')
      if len(pp) == 2
        if !has_key(ret, k)
          let ret[k] = []
        endif
        let n = substitute(pp[0], '[ \t\r\n]', '', 'g')
        let n = substitute(n, '/\*\_.\{-}\*/', '', 'g')
        let v = substitute(pp[1], '^\(\_\s\|/\*\_.\{-}\*/\)*', '', 'g')
        let v = substitute(v, '\(\_\s*\|/\*\_.\{-}\*/\)$', '', 'g')
        call add(ret[k], {
        \  'name': n,
        \  'value': v,
        \})
      endif
    endfor
  endfor
  return ret
endfunction

function! livestyle#lang#css#apply(patch)
  let patch = a:patch
  for p in patch
    if p['action'] == 'update'
      let pathex = join(map(copy(p['path']), 'v:val[0]'), '\\_\\s*,\\_\\s*')
      for prop in p['properties']
        let propex = '^\(\_.*\%(^\|\n\|}\)'.pathex.'\_\s{\_.*\<'.prop['name'].'\>\_\s*:\_\s*\)\(\_[^;]*\)\(\_.*\)$'
        let text = substitute(join(getline(1, '$'), "\n"), propex, '\1'.prop['value'].'\3', '')
        silent %d _
        call setline(1, split(text, "\n"))
      endfor
    elseif p['action'] == 'add'
      let text = join(getline(1, '$'), "\n")
      let text .= join(map(copy(p['path']), 'v:val[0]'), ', ') . " {\n"
      for prop in p['properties']
        let text .= '  ' . prop['name'] . ': ' . prop['value'] . ";\n"
      endfor
      let text .= "}\n"
      call setline(1, split(text, "\n"))
    elseif p['action'] == 'remove'
      let cx = '\\(\\_\\s*\\|/\\*\\_.\\{-}\\*/\\)'
      let ix = '\([a-zA-Z0-9-_.:]\+\|:\|''[^'']\+''\|;\+\|\_\s\+\|/\*\_.\{-}\*/\)*'
      let pathex = join(map(copy(p['path']), 'v:val[0]'), cx . ',' . cx)
      let ex = '^\(\_.*\%(^\|\n\|}\)\)'.pathex.cx.'{'.cx.ix.cx.'}\(\_.*\)'
      let text = substitute(join(getline(1, '$'), "\n"), ex, '\1\2', '')
      silent %d _
      call setline(1, split(text, "\n"))
    endif
  endfor
endfunction

function! livestyle#lang#css#diff(css1, css2)
  let [css1, css2] = [a:css1, a:css2]
  let patch = [[], []]
  let ks = keys(css1)
  for k in ks
    if !has_key(css2, k)
      call add(patch[0], {'action': 'remove', 'path':map(split(k, '\s*,\s*'), '[v:val, 1]')})
      call remove(css1, k)
    endif
  endfor
  for k in keys(css2)
    let removed = []
    if !has_key(css1, k)
      call add(patch[0], {'action': 'add', 'path':map(split(k, '\s*,\s*'), '[v:val, 1]'), 'properties': css2[k]})
      continue
    endif
    for p1 in css1[k]
      let found = 0
      for p2 in css2[k]
        if p2['name'] == p1['name']
          let found = 1
          break
        endif
      endfor
      if !found
        call add(removed, p1)
      endif
    endfor
    if len(removed) > 0
      call add(patch[0], {'action': 'update', 'path':map(split(k, '\s*,\s*'), '[v:val, 1]'), 'removed': removed})
    endif
    let properties = []
    for p2 in css2[k]
      let found = 0
      for p1 in css1[k]
        if p2['name'] == p1['name']
          let found = 1
          if p2['value'] != p1['value'] && len(p2['value']) > 0
            call add(properties, p2)
          endif
        endif
      endfor
      if !found
        call add(properties, p2)
      endif
    endfor
    if len(properties) > 0
      call add(patch[1], {'action': 'update', 'path':map(split(k, '\s*,\s*'), '[v:val, 1]'), 'properties': properties})
    endif
  endfor
  return patch
endfunction
