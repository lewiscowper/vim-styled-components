" Vim syntax file
" Language:   styled-components (js/ts)
" Maintainer: Karl Fleischmann <fleischmann.karl@gmail.com>
" URL:        https://github.com/styled-components/vim-styled-components

" store current indentexpr for later
let b:js_ts_indent=&indentexpr

" set indentexpr for this filetype (styled-components)
setlocal indentexpr=GetStyledIndent()

" add the following keys to trigger reindenting, when in insert mode
" - *;    - Indent and insert on press of ';' key.
" - *<:>  - Indent and insert on press of ':' key.
set indentkeys+=*;,*<:>,*<Return>

fu! s:GetSyntaxNames(lnum, cnum)
  return map(synstack(a:lnum, a:cnum), 'synIDattr(v:val, "name")')
endfu

" re-implement SynSOL of vim-jsx
" TODO: add dependency to the readme and remove duplicate implementation
fu! s:SynSOL(lnum)
  return s:GetSyntaxNames(a:lnum, 1)
endfu

" re-implement SynEOL of vim-jsx
" TODO: add dependency to the readme and remove duplicate implementation
fu! s:SynEOL(lnum, offset)
  let l:lnum = prevnonblank(a:lnum)
  let l:col = strlen(getline(l:lnum))

  return s:GetSyntaxNames(l:lnum, l:col + a:offset)
endfu


"" Return whether the current line is a jsTemplateString
fu! s:IsStyledDefinition(lnum)
  " iterate through all syntax items in the given line
  for item in s:SynSOL(a:lnum)
    " if syntax-item is a jsTemplateString return 1 - true
    " `==#` is a match case comparison of the item
    if item ==# 'styledDefinition'
      return 1
    endif
  endfor

  " fallback to 0 - false
  return 0
endfu

"" Count occurences of `str` at the beginning of the given `lnum` line
fu! s:CountOccurencesInSOL(lnum, str)
  let l:occurence = 0

  " iterate through all items in the given line
  for item in s:SynSOL(a:lnum)
    " if the syntax-item equals the given str increment the counter
    " `==?` is a case isensitive equal operation
    if item ==? a:str
      let l:occurence += 1
    endif
  endfor

  " return the accumulated count of occurences
  return l:occurence
endfu

"" Count occurences of `str` at the end of the given `lnum` line
fu! s:CountOccurencesInEOL(lnum, str, offset)
  let l:occurence = 0

  " iterate through all items in the given line
  for item in s:SynEOL(a:lnum, a:offset)
    " if the syntax-item equals the given str increment the counter
    " `==?` is a case insensitive equal operation
    if item == a:str
      let l:occurence += 1
    endif
  endfor

  " return the accumulated count of occurences
  return l:occurence
endfu

"" Get the indentation of the current line
fu! GetStyledIndent()
  if s:IsStyledDefinition(v:lnum)
    let l:baseIndent = 0

    " find last non-styled line
    let l:cnum = v:lnum
    while s:IsStyledDefinition(l:cnum)
      let l:cnum -= 1
    endwhile

    " get indentation of the last non-styled line as base indentation
    let l:baseIndent = indent(l:cnum)

    " incrementally build indentation based on current indentation
    " - one shiftwidth for the styled definition region
    " - one shiftwidth per open nested definition region
    let l:styledIndent = &sw
    let l:styledIndent += min([
          \ s:CountOccurencesInSOL(v:lnum, 'styledNestedRegion'),
          \ s:CountOccurencesInEOL(v:lnum, 'styledNestedRegion', 0)
          \ ]) * &sw

    " decrease indentation by one shiftwidth, if the styled definition
    " region ends on the current line
    " - either directly via styled definition region, or
    " - if the very last
    if s:CountOccurencesInEOL(v:lnum, 'styledDefinition', 1) == 0
      let l:styledIndent -= &sw
    endif

    " return the base indentation
    " (for nested styles inside classes/objects/etc.) plus the actual
    " indentation inside the styled definition region
    return l:baseIndent + l:styledIndent
  elseif len(b:js_ts_indent)
    let l:offset = 0

    " increase indentation by one shiftwidth, if the last line ended on a
    " styledXmlRegion and this line does not continue with it
    " this is a fix for an incorrectly indented xml prop after a
    " glamor-styled styledXmlRegion
    if s:CountOccurencesInEOL(v:lnum-1, 'styledXmlRegion', 0) == 1 &&
          \ s:CountOccurencesInSOL(v:lnum, 'styledXmlRegion') == 0
      let l:offset = &sw
    endif

    " use stored indentation function, if not inside of styledDefinition
    return eval(b:js_ts_indent) + l:offset
  endif

  " if all else fails indent according to C-syntax
  return cindent(v:lnum)
endfu
