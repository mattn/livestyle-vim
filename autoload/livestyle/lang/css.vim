function! livestyle#lang#css#init()
endfunction

function! livestyle#lang#css#parse(buf)
  let csss = split(a:buf, '[^{]\+{[^}]*}\zs\ze')
  let ret = {}
  for css in csss
    let t = split(css[:-2], '{')
    if len(t) != 2
      continue
    endif
    let k = substitute(t[0], '\s\+', '', 'g')
    for p in split(t[1], ';')
      let pp = split(p, '^[^:]\+\zs:\ze.*')
      if len(pp) == 2
        if !has_key(ret, k)
          let ret[k] = []
        endif
        call add(ret[k], {
        \  'name': substitute(pp[0], '[ \t\r\n]', '', 'g'),
        \  'value': substitute(pp[1], '[ \t\r\n]', '', 'g'),
        \})
      endif
    endfor
  endfor
  return ret
endfunction

function! livestyle#lang#css#diff(css1, css2)
  let [css1, css2] = [a:css1, a:css2]
  let patch = [[], []]
  let ks = keys(css1)
  for k in ks
    if !has_key(css2, k)
      call add(patch[0], {"action": "update", "path":[split(k, ',\s*')], "removed": css1[k]})
      call remove(css1, k)
    endif
  endfor
  for k in keys(css2)
    let removed = []
    if !has_key(css1, k)
      call add(patch[0], {"action": "update", "path":[split(k, ',\s*')], "removed": css2[k]})
      continue
    endif
    for p1 in css1[k]
      let found = 0
      for p2 in css2[k]
        if p2["name"] == p1["name"]
          let found = 1
          break
        endif
      endfor
      if !found
        call add(removed, p1)
      endif
    endfor
    if len(removed) > 0
      call add(patch[0], {"action": "update", "path":[split(k, ',\s*')], "removed": removed})
    endif
    let properties = []
    for p2 in css2[k]
      let found = 0
      for p1 in css1[k]
        if p2["name"] == p1["name"]
          if p2["value"] != p1["value"] && len(p2["value"]) > 0
            let found = 1
            call add(properties, p2)
          endif
        endif
      endfor
      if !found
        call add(properties, p2)
      endif
    endfor
    if len(properties) > 0
      call add(patch[1], {"action": "update", "path":[split(k, ',\s*')], "properties": properties})
    endif
  endfor
  return patch
endfunction
