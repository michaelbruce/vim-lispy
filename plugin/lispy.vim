" vim-lispy
" Author:       Michael Bruce <http://focalpointer.org/>
" Version:      0.1
" " map <Leader>5 :unlet g:loaded_alternator<CR>:so %<CR>:echo 'Reloaded!'<CR>
"
" PROGRESS
" - TODO Balanced pairs, only () is handles for closing, nearly there though
" - TODO Wrap round, accomplished by vim-surround, custom keybinding for this?w
" - TODO protip, look at rainbow parens to see how context can be programmed "   here
" - TODO deleting, M-d done, paredit-kill & C-w being implemented
" - TODO slurping, expanding the current sexp to accomodate neighbouring code
" - TODO barfing, contracting the current sexp by spitting out code at the  edge

" TODO list balancing
"   - TODO checking whole project is balanced
" Overrides my => binding. problem?
" Paredit is 1753 lines long

" Match delimiter this number of lines before and after cursor position

let g:paredit_mode = 1

if !exists( 'g:paredit_matchlines' )
    let g:paredit_matchlines = 100
endif

" Skip matches inside string or comment or after '\'
let s:skip_sc = '(synIDattr(synID(line("."), col("."), 0), "name") =~ "[Ss]tring\\|[Cc]omment\\|[Ss]pecial\\|clojureRegexp\\|clojurePattern" || getline(line("."))[col(".")-2] == "\\")'

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

    " -- Keybindings
    " Implicit Editing behaviour
    inoremap <buffer> <expr>   (            PareditInsertOpening('(',')')
    inoremap <buffer> <expr>   )            LispyCloseIfUnmatched(')')
    inoremap <buffer> <expr>   {            PareditInsertOpening('{','}')
    inoremap <buffer> <expr>   [            PareditInsertOpening('[',']')
    inoremap <buffer> <expr>   "            PareditInsertOpening('"','"')
    inoremap <buffer> <expr>   <BS>         PareditBackspace(0)
    " Handy cursor movements
    inoremap <C-f>        <C-o>l
    inoremap <C-b>        <C-o>h
    " F( should be replaced with a backward search for any open/closing list
    " F[...
    set <M-k>=k
    imap <M-k> <C-o>:call SlurpRight()<CR>
    map <M-k> :call SlurpRight()<CR>
    " TODO find a suitable binding for Kick that actually works
    " imap <C-k> <C-o>:call Kick()<CR>
    " map <C-k> :call Kick()<CR>
    inoremap <C-d>        <C-o>x
    inoremap <C-k>        <C-o>F(<BS><CR><C-o>%
    " TODO BS mapping does not work as intended
    noremap <BS> :RainbowParenthesis!!
    " inoremap <C-F>        <C-o>k " slurp/barfing
    " splicing achieved with ds(/dsb
    " wrap entire line with yssb
endfunction

" Valid macro prefix characters
let s:any_macro_prefix   = "'" . '\|`\|#\|@\|\~\|,\|\^'

" === Handy Macros -------------------------------------------------------------------

function! LispyNextLineSplit()
    let start_line = getline( '.' )
    let start_column = col( '.' ) - 1
    " Move to cut point
    let cut_column = col( '.' ) - 1
endfunction

function! Kick()
  normal f)x$p
endfunction

" === Implicit Editing behaviour -----------------------------------------------------

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

" TODO if in function name signals refactoring
function! LispyCloseIfUnmatched( close )
    let line = getline( '.' )
    let pos = col( '.' ) - 1
    " TODO work for parens first, then generalise
    if line[pos] == ')'
        return "\<C-o>a"
    else
        return ")"
    end
endfunction

" TODO needs testing
function! LispyKill()
    normal dt)
endfunction

function! s:letter_under_cursor()
    return matchstr(getline('.'), '\%' . col('.') . 'c.')
endfunction

function! SlurpRight()
    if s:letter_under_cursor() != ')'
        normal f)
    endif
    normal "yx
    " you will likely need a conditional to check that a paren is not already
    " side by side to another before searching. )) will stay as ))
    normal / \|)
    normal "yP
endfunction

function! BarfRight()
endfunction

" Handle <BS> keypress
function! PareditBackspace( repl_mode )
    " let [lp, cp] = s:GetReplPromptPos()
    " if a:repl_mode && line( "." ) == lp && col( "." ) <= cp
    "     " No BS allowed before the previous EOF mark in the REPL
    "     " i.e. don't delete Lisp prompt
    "     return ""
    " endif

    if !g:paredit_mode " || s:InsideComment()
        return "\<BS>"
    endif

    let line = getline( '.' )
    let pos = col( '.' ) - 1

    if pos == 0
        " We are at the beginning of the line
        return "\<BS>"
    elseif s:InsideString() && line[pos-1] =~ b:any_openclose_char
        " Deleting a paren inside a string
        return "\<BS>"
    elseif pos > 1 && line[pos-1] =~ b:any_matched_char && line[pos-2] == '\' && (pos < 3 || line[pos-3] != '\')
        " Deleting an escaped matched character
        return "\<BS>\<BS>"
    elseif line[pos-1] !~ b:any_matched_char
        " Deleting a non-special character
        return "\<BS>"
    elseif line[pos-1] != '"' && !s:IsBalanced()
        " Current top-form is unbalanced, can't retain paredit mode
        return "\<BS>"
    endif

    if line[pos-1:pos] =~ b:any_matched_pair
        " Deleting an empty character-pair
        return "\<Right>\<BS>\<BS>"
    else
        " Character-pair is not empty, don't delete just move inside
        return "\<Left>"
    endif
endfunction

" === Composable functions

" Does the current syntax item match the given regular expression?
function! s:SynIDMatch( regexp, line, col, match_eol )
    let col  = a:col
    if a:match_eol && col > len( getline( a:line ) )
        let col = col - 1
    endif
    return synIDattr( synID( a:line, col, 0), 'name' ) =~ a:regexp
endfunction

" Is the current cursor position inside a string?
function! s:InsideString( ... )
    let l = a:0 ? a:1 : line('.')
    let c = a:0 ? a:2 : col('.')
    if &syntax == ''
        " No help from syntax engine,
        " count quote characters up to the cursor position
        let line = strpart( getline(l), 0, c - 1 )
        let line = substitute( line, '\\"', '', 'g' )
        let quotes = substitute( line, '[^"]', '', 'g' )
        return len(quotes) % 2
    endif
    " VimClojure and vim-clojure-static define special syntax for regexps
    return s:SynIDMatch( '[Ss]tring\|clojureRegexp\|clojurePattern', l, c, 0 )
endfunction

" Is the current top level form balanced, i.e all opening delimiters
" have a matching closing delimiter
function! s:IsBalanced()
    let l = line( '.' )
    let c =  col( '.' )
    let line = getline( '.' )
    if c > len(line)
        let c = len(line)
    endif
    let matchb = max( [l-g:paredit_matchlines, 1] )
    let matchf = min( [l+g:paredit_matchlines, line('$')] )
    " let [prompt, cp] = s:GetReplPromptPos()
    " if s:IsReplBuffer() && l >= prompt && matchb < prompt
    "     " Do not go before the last command prompt in the REPL buffer
    "     let matchb = prompt
    " endif
    let p1 = searchpair( '(', '', ')', 'brnmW', s:skip_sc)
    let p2 = searchpair( '(', '', ')',  'rnmW', s:skip_sc)
    if !(p1 == p2) && !(p1 == p2 - 1 && line[c-1] == '(') && !(p1 == p2 + 1 && line[c-1] == ')')
        " Number of opening and closing parens differ
        return 0
    endif

    if &ft =~ '.*\(clojure\|scheme\|racket\).*'
        let b1 = searchpair( '\[', '', '\]', 'brnmW', s:skip_sc)
        let b2 = searchpair( '\[', '', '\]',  'rnmW', s:skip_sc)
        if !(b1 == b2) && !(b1 == b2 - 1 && line[c-1] == '[') && !(b1 == b2 + 1 && line[c-1] == ']')
            " Number of opening and closing brackets differ
            return 0
        endif
        let b1 = searchpair( '{', '', '}', 'brnmW', s:skip_sc)
        let b2 = searchpair( '{', '', '}',  'rnmW', s:skip_sc)
        if !(b1 == b2) && !(b1 == b2 - 1 && line[c-1] == '{') && !(b1 == b2 + 1 && line[c-1] == '}')
            " Number of opening and closing curly braces differ
            return 0
        endif
    endif
    return 1
endfunction

au FileType *clojure* call LispyInitBuffer()
