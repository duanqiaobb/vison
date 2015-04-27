"============================================================================
" FILE: autoload/vison.vim
" AUTHOR: Quramy <yosuke.kurami@gmail.com>
"============================================================================

scriptencoding utf-8

let s:V = vital#of('vison')
let s:File = s:V.import('System.File')
let s:Filepath = s:V.import('System.Filepath')
let s:base_dir = expand('<sfile>:p:h:h')

function! vison#base_dir()
  return s:base_dir
endfunction

" ### Setup {{{
function! vison#setup()
  return vison#store#setup()
endfunction
" ### Setup }}}

" ### Switch schema type {{{
let s:type_map = {}
function! vison#switch_type(...)
  if a:0 == 0
    let schemaname = expand('%:t')
    let buf_name = expand('%:p')
  elseif a:0 == 1
    let schemaname = a:1
    let buf_name = expand('%:p')
  elseif a:0 > 1
    let schemaname = a:1
    let buf_name = expand(a:2)
  else
    return
  endif
  if buf_name == ''
    return
  endif
  let [matched, schema_path] = vison#store#get_schemafile(schemaname, 0)
  if !matched
    call vison#misc#log_warn('Cannot find schema: "'.schemaname.'". Try :VisonSetup or :VisonRegister to install schema file.')
    return
  endif
  let s:type_map[buf_name] = schemaname
  let b:is_cached_dict = 0
  setlocal omnifunc=vison#complete
endfunction

function! vison#switch_type_complete(ArgLead, CmdLine, CursorPos)
  let key_list = vison#store#get_schemanames()
  let matched = []
  for key_str in key_list
    if stridx(key_str, a:ArgLead) == 0
      call add(matched, key_str)
    endif
  endfor 
  return matched
endfunction
" ### Switch Schema type }}}

" ### Complete {{{
function! vison#complete(findstart, base)
   if a:findstart
    " Search schema
    if !exists('b:is_cached_dict') || !b:is_cached_dict
      let schemaname = s:type_map[expand('%:p')]
      let [matched, schema_path] = vison#store#get_schemafile(schemaname, 0)
      if !matched
        return -3
      endif
      let [b:is_cached_dict, b:cached_dict] = [1, vison#misc#load(schema_path)]
    endif

    " Get query from the current buffer.
    let [b:type, b:query] = vison#resolver#get_query(getline(0, line('.')))

    " Search backwards for start of identifier (iskeyword pattern)
    let l:line_str = getline('.')
    let l:start = col('.')
    while l:start > 0 && l:line_str[l:start - 2] =~ "\\k"
      let l:start -= 1
    endwhile
    return l:start - 1
  else
    " if b:type == -1
    "   return []
    " elseif b:type == 0
    "   "TODO
    "   return []
    " endif

    return vison#resolver#complete(b:cached_dict, b:type, b:query, a:base)

  endif
endfunction
" ### Complete }}}

" ### Register {{{
function! vison#register_schema(group_name, type_name)
  if a:type_name == ''
    echom '[vison] Schema name is empty.'
    return
  endif

  return vison#store#register(a:group_name, a:type_name, getline(0, '$'))
endfunction

function! vison#register_default_schema(...)
  if a:0 > 1
    let type_name = a:1
  else
    let type_name = expand('%:t')
  endif
  call vison#register_schema('default', type_name)
endfunction
" ### Register }}}

function! s:complete_core()
  " underscore charactor stands for the cursor position.
  " case 1: {_
  "   should complete enbale key names.
  "   {query: '', base: ''}
  " case 2: { "ho_
  "   should complete enable key names.
  "   {query: '', base: 'ho'}
  " case 3: { "hoge"_
  "   should nothing. User may type ':' charactor.
  "   {query: 'hoge', base: ''}
  " case 4: { "hoge" :_
  "   should complete enable strings or '[' or '{'.
  "   {query: 'hoge', base: ''}
  " case 5: { "hoge" : "f\"o_
  "   {query: 'hoge', base: 'f\"o'}
  "   should complete enable strings.
  " case 6: { "hoge" : [_
  "   should complete enable strings or '{'.
  "   {query: 'hoge[0]', base: ''}
  " case 7: { "hoge": { "foo": [{ "bar": "pi_
  "   {query: 'hoge.foo[0].bar', base: 'pi'}
  " case 8: { "hoge" : ["foo", "ba_
  "   should complete enable strings or '{'.
  "   {query: 'hoge[0]', base: 'ba'}
  "
  " Algorithm
  " { "hoge": { "foo": [{ "bar": "pi_
  " to 
  " [ '{', ' "hoge"', ':', '{', " foo", ':', '[', '{', ' "bar"', ':', '"pi_']
endfunction

