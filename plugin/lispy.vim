" vim-lispy
" Author:       Michael Bruce <http://focalpointer.org/>
" Version:      0.1
" " map <Leader>5 :unlet g:loaded_alternator<CR>:so %<CR>:echo 'Reloaded!'<CR>

" TODO list balancing
"   - TODO checking whole project is balanced

function! LispyInitBuffer ()
    let b:paredit_init = 1
    " in case they are accidentally removed
    " Also define regular expressions to identify special characters used by paredit
    if &ft =~ '.*\(clojure\|scheme\|racket\).*'
        let b:any_matched_char   = '(\|)\|\[\|\]\|{\|}\|\"'
        let b:any_matched_pair   = '()\|\[\]\|{}\|\"\"'
        let b:any_opening_char   = '(\|\[\|{'
        let b:any_closing_char   = ')\|\]\|}'
        let b:any_openclose_char = '(\|)\|\[\|\]\|{\|}'
        let b:any_wsopen_char    = '\s\|(\|\[\|{'
        let b:any_wsclose_char   = '\s\|)\|\]\|}'
    else
        let b:any_matched_char   = '(\|)\|\"'
        let b:any_matched_pair   = '()\|\"\"'
        let b:any_opening_char   = '('
        let b:any_closing_char   = ')'
        let b:any_openclose_char = '(\|)'
        let b:any_wsopen_char    = '\s\|('
        let b:any_wsclose_char   = '\s\|)'
    endif

    inoremap <buffer> <expr>   (            PareditInsertOpening('(',')')
    inoremap <buffer> <expr>   {            PareditInsertOpening('{','}')
    inoremap <buffer> <expr>   [            PareditInsertOpening('[',']')
    inoremap <buffer> <expr>   "            PareditInsertOpening('"','"')
    inoremap <C-f>        <C-o>l
    inoremap <C-b>        <C-o>h
    " Overrides my => binding. problem?
    " F( should be replaced with a backward search for any open/closing list
    " symbol (/{/[/]/}/)
    inoremap <C-k>        <C-o>F(<BS><CR><C-o>%
    " noremap <BS> RainbowParenthesis!!
    " inoremap <C-F>        <C-o>k " slurp/barfing
    " splicing achieved with ds(/dsb
    " wrap entire line with yssb
endfunction

" Valid macro prefix characters
let s:any_macro_prefix   = "'" . '\|`\|#\|@\|\~\|,\|\^'

function! LispyNextLineSplit()
    let start_line = getline( '.' )
    let start_column = col( '.' ) - 1
    " Move to cut point
    let cut_column = col( '.' ) - 1
endfunction

" Insert opening type of a paired character, like ( or [.
function! PareditInsertOpening( open, close )
    " if !g:paredit_mode || s:InsideComment() || s:InsideString() || !s:IsBalanced()
    "     return a:open
    " endif
    let line = getline( '.' )
    let pos = col( '.' ) - 1
    if pos > 0 && line[pos-1] == '\' && (pos < 2 || line[pos-2] != '\')
        " About to enter a \( or \[
        return a:open
    elseif line[pos] !~ b:any_wsclose_char && pos < len( line )
        " Add a space after if needed
        let retval = a:open . a:close . " \<Left>\<Left>"
    else
        let retval = a:open . a:close . "\<Left>"
    endif
    if pos > 0 && line[pos-1] !~ b:any_wsopen_char && line[pos-1] !~ s:any_macro_prefix
        " Add a space before if needed
        let retval = " " . retval
    endif
    return retval
endfunction
