set tabstop=8
set softtabstop=0
set expandtab
set shiftwidth=4
set smarttab
set number
set colorcolumn=81

syntax on
filetype plugin indent on
let g:markdown_fenced_languages = ["sh", "bash=sh", "js=javascript", "javascript", "ts=typescript", "typescript", "json", "toml", "lua", "python", "diff"]
set termguicolors
set background=dark
colorscheme retrobox

" Markdown at maximum color. Stock markdown syntax only marks headings,
" emphasis, code and links, so this also colors list markers, paths, file
" names, flags, <placeholders>, "quotes", ALLCAPS, numbers and short
" heading-like lines with no '#'. Palette is gruvbox, to match retrobox.
function! s:MarkdownColors() abort
  " A '_' inside a word (AGENTS_SUGGEST) is not an error.
  hi link markdownError NONE
  syn case match
  syn match mdPath /\%(\~\|\.\{1,2}\)\?\%([[:alnum:]_.@<>*-]*\/\)\+[[:alnum:]_.@<>*-]*/
  syn match mdFile /\<[[:alnum:]_.-]\+\.\%(md\|sh\|js\|mjs\|ts\|tsx\|json\|toml\|vim\|lua\|py\|yml\|yaml\|txt\|css\|html\)\>/
  syn match mdFlag /\%(^\|\s\)\zs--\?\a[[:alnum:]-]*/
  syn match mdPlaceholder /<[[:alnum:]_ -]\+>/
  syn match mdQuote /"[^"]*"/
  syn match mdCaps /\<\u[[:upper:][:digit:]_]\+\>/
  syn match mdNumber /\<\d[[:digit:].:-]*\>/
  " Defined last so it wins over the word-level matches above.
  syn match mdLooseHeading /^\u[[:alnum:] /&'()-]\{0,48}[[:alnum:])]$/

  hi markdownH1 guifg=#fb4934 gui=bold
  hi markdownH2 guifg=#fabd2f gui=bold
  hi markdownH3 guifg=#b8bb26 gui=bold
  hi markdownH4 guifg=#83a598 gui=bold
  hi markdownH5 guifg=#d3869b gui=bold
  hi markdownH6 guifg=#8ec07c gui=bold
  hi link markdownH1Delimiter markdownH1
  hi link markdownH2Delimiter markdownH2
  hi link markdownH3Delimiter markdownH3
  hi link markdownH4Delimiter markdownH4
  hi link markdownH5Delimiter markdownH5
  hi link markdownH6Delimiter markdownH6
  hi link markdownHeadingDelimiter markdownH1
  hi mdLooseHeading guifg=#fabd2f gui=bold,underline
  hi markdownBold guifg=#fe8019 gui=bold
  hi markdownItalic guifg=#d3869b gui=italic
  hi markdownBoldItalic guifg=#fb4934 gui=bold,italic
  hi markdownCode guifg=#8ec07c guibg=#3c3836
  hi markdownCodeBlock guifg=#83a598 guibg=#32302f
  hi markdownCodeDelimiter guifg=#928374 guibg=#3c3836
  hi markdownLinkText guifg=#83a598 gui=underline
  hi markdownUrl guifg=#458588 gui=underline
  hi markdownListMarker guifg=#fe8019 gui=bold
  hi markdownOrderedListMarker guifg=#fe8019 gui=bold
  hi markdownBlockquote guifg=#928374 gui=italic
  hi markdownRule guifg=#d3869b gui=bold
  hi mdPath guifg=#8ec07c
  hi mdFile guifg=#d3869b gui=bold
  hi mdFlag guifg=#fe8019
  hi mdPlaceholder guifg=#fb4934 gui=italic
  hi mdQuote guifg=#b8bb26
  hi mdCaps guifg=#fabd2f
  hi mdNumber guifg=#d3869b
endfunction

augroup markdown_colors
  autocmd!
  autocmd Syntax markdown call s:MarkdownColors()
augroup END

" gruvbox look: lighter background, yellow line numbers, colored status line
" with the mode in a block (NORMAL purple, INSERT green, VISUAL orange).
function! s:GruvboxLook() abort
  hi Normal guibg=#282828
  hi LineNr guifg=#fabd2f guibg=#282828
  hi CursorLineNr guifg=#fe8019 gui=bold
  hi EndOfBuffer guibg=#282828
  hi ColorColumn guibg=#3c3836
  hi StatusLine guifg=#ebdbb2 guibg=#504945 gui=NONE
  hi StatusLineNC guifg=#928374 guibg=#3c3836 gui=NONE
  hi slNormal guifg=#282828 guibg=#d3869b gui=bold
  hi slInsert guifg=#282828 guibg=#b8bb26 gui=bold
  hi slVisual guifg=#282828 guibg=#fe8019 gui=bold
  hi slReplace guifg=#282828 guibg=#fb4934 gui=bold
  hi slFile guifg=#ebdbb2 guibg=#665c54 gui=bold
  hi slType guifg=#8ec07c guibg=#504945
  hi slPos guifg=#282828 guibg=#fabd2f gui=bold
endfunction
call s:GruvboxLook()
augroup gruvbox_look
  autocmd!
  autocmd ColorScheme * call s:GruvboxLook()
augroup END

function! StatusMode() abort
  let m = mode()
  let [group, name] = m =~# '^i' ? ['slInsert', 'INSERT']
        \ : m =~# "^[vV\<C-v>]" ? ['slVisual', 'VISUAL']
        \ : m =~# '^R' ? ['slReplace', 'REPLACE']
        \ : ['slNormal', 'NORMAL']
  return '%#' . group . '# ' . name . ' '
endfunction
set laststatus=2 noshowmode
set statusline=%{%StatusMode()%}%#slFile#\ %f%m%r\ %#StatusLine#%=%#slType#\ %y\ %{&fenc}\ %#slPos#\ %p%%\ %l:%c\ 
