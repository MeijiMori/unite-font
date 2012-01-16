" =============================================================================
" File: font.vim <Unite source file>
" Ex:   Replace font selecter ?
" Todo: Restore windowsize
"       Invite space in font name
" Note: Refer to unite-font/autoload/unite/source/font.vim.org <- original file (ujihisa's plugin)
"       Refer to fontzoom.vim (thinca's plugin)
" =============================================================================

let s:save_cpo = &cpo
set cpo&vim

" Variables "{{{
let s:iswin = has('win16') || has('win32') || has('win64')
if s:iswin
  " command pass
  " let s:fontinfo_cmd_pass = expand('~/.vim/bundle/unite-font/bin/fontinfo.exe')
  let remove_pass_pattern = 'autoload/unite/sources'
  let replace_pass_pattern = 'bin/fontinfo.exe'
  let s:fontinfo_cmd_pass = expand('<sfile>:h:gs?' . remove_pass_pattern . '?' . replace_pass_pattern . '?')
else
  let s:fc-list_cmd_pass = expand('/usr/bin/fc-list')
endif

" Font size pattern
let s:set_font_size_pattern =
      \   has('win32') || has('win64') ||
      \   has('mac') || has('macunix') ? ':h\zs\d\+':
      \   has('gui_gtk')               ? '\s\+\zs\d\+$':
      \   has('X11')                   ? '\v%([^-]*-){6}\zs\d+\ze%(-[^-]*){7}':
      \                                  '*Unknown system*'

" Font style pattern
let s:set_font_style_pattern =
      \ has('win32') || has('win64') ? ':\zs[bius]\+' :
      \ has('mac') || has('macunix') ? '' :
      \ has('gui_gtk')               ? '' :
      \ has('X11')                   ? '' :
      \                                '*Unknown system*'

" Save window size and font
" let s:keep = [&guifont, &lines, &columns]

"}}}

let s:unite_source = {
      \ 'name' : 'font',
      \ 'description' : 'candidates from system font that able to use',
      \ 'hooks' : {},
      \ 'action_table' : {},
      \ }

" functions "{{{

" Define
function! unite#sources#font#define() "{{{
  return has('gui_running') ? s:unite_source : []
endfunction "}}}

" Main
function! s:unite_source.gather_candidates(args, context) "{{{

  let type = get(a:args, 0)
  if type =~? 'wide'
    let s:font_type = &guifontwide
    let s:command = "guifontwide"
  else
    let s:font_type = &guifont
    let s:command = "guifont"
  endif
  " Debug "{{{
  " echomsg "type : " . type
  "}}}

  let result = []

  " Debug "{{{
  " if s:iswin
  "   echomsg 's:fontinfo_cmd_pass : ' . s:fontinfo_cmd_pass
  " else
  "   echomsg 's:fc-list_cmd_pass : ' . s:fc-list_cmd_pass
  " endif
  " }}}

    call add(result, {
          \ "word" : s:font_type,
          \ "abbr" : printf("%-25s %s", s:font_type, "This font Booting font source"),
          \ "source" : "font",
          \ "kind" : "command",
          \ "action__command" : "let &" . s:command . "=" . string(s:font_type)
          \ })

  " get system fonts "{{{
  if has('gui_macvim')
    let list = split(glob('/library/fonts/*'), "\n")
    let list = extend(list, split(glob('/system/library/fonts/*'), "\n"))
    let list = extend(list, split(glob('~/library/fonts/*'), "\n"))
    call map(list, "fnamemodify(v:val, ':t:r')")
  elseif (has('win32') || has('win64')) && executable(s:fontinfo_cmd_pass)
    " use vimproc
    try
      let s:exists_vimproc_version = vimproc#version()
      let list = split(iconv(vimproc#system(s:fontinfo_cmd_pass), 'utf-8', &encoding), "\n")
    catch
      " echomsg "Don't use vimproc"
      let list = split(iconv(system(s:fontinfo_cmd_pass), 'utf-8', &encoding), "\n")
    endtry
  elseif executable('fc-list')
    " 'fc-list' for win32 is included 'gtk win32 runtime'.
    " see: http://www.gtk.org/download-windows.html
    let list = split(iconv(system('fc-list :spacing=mono'), 'utf-8', &encoding), "\n")
    if v:lang =~ '^\(ja\|ko\|zh\)'
      let list += split(iconv(system('fc-list :spacing=90'), 'utf-8', &encoding), "\n")
    endif
    call map(list, "substitute(v:val, '[:,].*', '', '')")
  else
    echoerr 'your environment does not support the current version of unite-font.'
    finish
  endif
  "}}}

  let size = s:iswin ? ':h' . s:fon_size :
             \ has('gui_gtk')   ? ' \ ' . s:fon_size :
             \ has('x11')       ? ' \ ' . s:fon_size :
             \                    '*unknown system*'
  let style = s:fon_style

  if s:command =~?  "guifont"
    let demonstration = '[<wWoO0iI1lL!"#$%&''^\()>]'
  else
    let demonstration = '[あいうえおアイウエオ]'
  endif

  " Debug"{{{
  " for sys_font in list
  "   echomsg sys_font
  " endfor
  " echomsg "font size : " . s:fon_size
  " echomsg "demonstration : " . demonstration
  " echomsg "s:command : " . s:command
  "}}}

  for sys_font in list
    call add(result, {
          \ "word" : sys_font,
          \ "abbr" : printf('%-25s %s', sys_font,  demonstration),
          \ "source" : "font",
          \ "kind" : "command",
          \ "action__command" : "let &" . s:command . "=" . string(sys_font . size),
          \ })
  endfor

  return result

endfunction "}}}

" Actions
" Add custom action table "{{{

" size
let s:unite_source.action_table.change_size = {
      \ 'description' : 'change selected font size',
      \ 'is_invalidate_cache' : 1,
      \ 'is_quit' : 0,
      \ 'is_selectable' : 0,
      \ }

" size change
function! s:unite_source.action_table.change_size.func(candidate) "{{{

  " default font size
  let default_size = s:get_font_size()
  " Debug"{{{
  " echomsg "default_size : " . default_size
  "}}}
  if default_size == ''
    if s:iswin
      let default_size = '10'
    else
      let default_size = '13'
    endif
  endif

  let size = input("input font size : ", default_size)

  " Debug "{{{
  " echomsg " input size : " . size
  "}}}

  if size == ''
    let n_size = s:get_font_size()
    echo n_size
  else
    let s:fon_size = size

    if !exists('s:keep')
      let s:keep = [&guifont, &guifontwide, &lines, &columns]
    endif

    " let &guifont = join(map(split(a:candidate.word, '\\\@<!,'),
    "       \   printf('substitute(v:val, %s, %s, "g")',
    "       \   string(s:set_font_size_pattern),
    "       \   string('\=max([1,' . size . '])'))), ',')

    " Debug"{{{
    " echomsg "a:candidate.word : " . a:candidate.word
    " echomsg "a:candidate.action__command : " . a:candidate.action__command
    " echomsg "&guifont : " . &guifont
    " echomsg "&guifontwide : " . &guifontwide
    "}}}

    if s:iswin || has('mac') || has('macunix')
      if s:command == "guifont"
        " Debug"{{{
        " echomsg "Debug : " . s:command
        " echomsg "&guifont : " . &guifont
        " echomsg "&guifontwide : " . &guifontwide
        "}}}
        let convert_font_name = substitute(a:candidate.word, '\:h\d*', '', 'g')
        let convert_fontw_name = substitute(&guifontwide, '\:h\d*', '', 'g')
        let &guifont = convert_font_name . ':h' . size
        let &guifontwide = convert_fontw_name . ':h' . size
        " Debug"{{{
        " echomsg "convert_font_name : " . convert_font_name
        " echomsg "convert_fontw_name : " . convert_fontw_name
        "}}}
      elseif s:command == "guifontwide"
        " Debug"{{{
        " echomsg "Debug : " . s:command
        " echomsg "&guifont : " . &guifont
        " echomsg "&guifontwide : " . &guifontwide
        "}}}
        let convert_font_name = substitute(&guifont, '\:h\d*', '', 'g')
        let convert_fontw_name = substitute(a:candidate.word, '\:h\d*', '', 'g')
        let &guifont = convert_font_name . ':h' . size
        let &guifontwide = convert_fontw_name . ':h' . size
        " Debug"{{{
        echomsg "convert_font_name : " . convert_font_name
        echomsg "convert_fontw_name : " . convert_fontw_name
        "}}}
      endif
    else
      echomsg "else : "
      let convert_font_name = a:candidate.word
      let &guifont = convert_font_name . '\ ' . size
    endif

    " Debug"{{{
    " echomsg "convert_font_name : " . convert_font_name
    " echomsg "convert_fontw_name : " . convert_fontw_name
    "}}}

    " keep window size if possible.
    let [&lines, &columns] = s:keep[2 :]

    " Debug"{{{
    " echomsg "replaced_sp_font_name : " . replaced_sp_font_name
    " echomsg "convert_font_name : " . convert_font_name
    " echomsg "&guifont : " . &guifont
    " echomsg "lines : " . &lines
    " echomsg "columns : " . &columns
    " echomsg "split(a:candidate.word, '\\\@<!,') : "
    " let ss = split(a:candidate.word, '\\\@<!,')
    " for item in ss
    "   echomsg "item : " . item
    " endfor
    "}}}

  endif

  " Debug "{{{
  " echomsg "a:candidate.word : " . a:candidate.word
  " echomsg "a:candidate.source : " . a:candidate.source
  " echomsg "a:candidate.kind : " . a:candidate.kind
  " echomsg "a:candidate.action__command : " . a:candidate.action__command
  " }}}

endfunction "}}}

" style
let s:unite_source.action_table.change_style = {
      \ 'description' : 'change selected font style',
      \ 'is_invalidate_cache' : 1,
      \ 'is_quit' : 0,
      \ 'is_selectable' : 0,
      \ }

" style change
function! s:unite_source.action_table.change_style.func(candidates) "{{{

  " default font style
  if s:iswin
    let default_style = ""
  else
    let default_style = s:get_font_style()
  endif

  let style = input("input font style : ", default_style)

  " Debug"{{{
  " echomsg "input style : " . style
  "}}}

  if style == ''
    let n_style = default_style
    echo n_style
  else

    if s:iswin || has('mac') || has('macunix')
    else
    endif

endfunction "}}}

" preview
let s:unite_source.action_table.preview = {
      \ 'description' : 'preview this font',
      \ 'is_quit' : 0,
      \ }

function! s:unite_source.action_table.preview.func(candidate)"{{{
  execute a:candidate.action__command
endfunction"}}}

" }}}

" Hooks
" init
function! s:unite_source.hooks.on_init(args, context) "{{{
  let s:beforefont = &guifont
  let s:beforefontwide = &guifontwide
  let s:fon_size = s:get_font_size()
  let s:beforesize = s:fon_size
  let s:fon_style = s:get_font_style()

  " Debug"{{{
  " echomsg "On_init s:beforefont : " . s:beforefont
  " echomsg "On_init s:font_size : " . s:fon_size
  " echomsg "On_init s:font_style : " . s:fon_style
  "}}}

endfunction "}}}

" close
function! s:unite_source.hooks.on_close(args, context) "{{{

  if !exists('s:keep')
    let s:keep = [&guifont, &guifontwide, &lines, &columns]
  endif
  " keep window size if possible.
  let [&lines, &columns] = s:keep[2 :]

  " Debug"{{{
  " echomsg "On_close s:beforefont : " . s:beforefont
  " echomsg "On_close &guifont : " . &guifont
  " echomsg "On_close s:fon_size : " . s:fon_size
  " echomsg "On_close beforesize : " . s:beforesize
  "}}}

  if s:command == "guifont"
    if s:beforefont == &guifont && s:beforesize == s:fon_size
      echomsg 'return'
      return
    elseif s:beforefont == &guifont && s:beforesize != s:fon_size
      execute "let &guifont=" . string(s:beforefont . s:fon_size)
    else
      execute "let &guifont=" . string(s:beforefont)
    endif
  elseif s:command == "guifontwide"
    if s:beforefontwide == &guifontwide && s:beforesize == s:fon_size
      echomsg 'return:wide'
      return
    elseif s:beforefontwide == &guifontwide && s:beforesize != s:fon_size
      execute "let &guifontwide=" . string(s:beforefontwide . s:fon_size)
    else
      execute "let &guifontwide=" . string(s:beforefontwide)
    endif
  endif
endfunction "}}}

" Utility
" now size
function! s:get_font_size() "{{{
  return matchstr(&guifont, s:set_font_size_pattern)
endfunction "}}}

" now style
function! s:get_font_style() "{{{
  let style = matchstr(&guifont, s:set_font_style_pattern)
  if style  ==  ''
    let fon_style = 'none'
  elseif style == 'b'
    let fon_style = 'bold'
  elseif style == 'i'
    let fon_style = 'italic'
  elseif style == 'u'
    let fon_style = 'underline'
  elseif style == 's'
    let fon_style = 'midleline'
  endif

  return fon_style

endfunction "}}}

"}}}

let &cpo = s:save_cpo
unlet s:save_cpo
