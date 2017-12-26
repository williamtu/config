set enc=utf-8
set fenc=utf-8
set termencoding=utf-8
" disable vi compatibility (emulation of old bugs)
set nocompatible
" " use indentation of previous line
set autoindent
" " use intelligent indentation for C
set smartindent
" " configure tabwidth and insert spaces instead of tabs
set tabstop=8       " tab width is 4 spaces
set shiftwidth=8     " indent also with 4 spaces
"set expandtab        " expand tabs to spaces
" " wrap lines at 120 chars. 80 is somewaht antiquated with nowadays displays.
set textwidth=120
 " turn syntax highlighting on
set t_Co=256
syntax on
" " colorscheme wombat256
" " turn line numbers on
set number
" " highlight matching braces
set showmatch
" " intelligent comments
set comments=sl:/*,mb:\ *,elx:\ */
set hlsearch
set colorcolumn=80
cs add .
"set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<,space:␣
set listchars=tab:>.,trail:.,extends:#,nbsp:. " Highlight problematic whitespace
"set list

let g:linuxsty_patterns = [ "/root/net-next/" ]
map <F7> :setlocal spell! spelllang=en_nz<CR>

" Pathogen
execute pathogen#infect()

" GitGutter
let g:gitgutter_enabled = 0
noremap <F5> :GitGutterToggle<CR>
nmap <F3> <Plug>GitGutterPrevHunk
nmap <F4> <Plug>GitGutterNextHunk

" Cscope maps
" g: find this definition
" c: find functions calling this function
" s: find this C symbol
" d: find functions called by this function
nmap <Leader>g :cs find g <C-R>=expand("<cword>")<CR><CR>
nmap <Leader>c :cs find c <C-R>=expand("<cword>")<CR><CR>
nmap <Leader>s :scs find s <C-R>=expand("<cword>")<CR><CR>
nmap <Leader>d :scs find d <C-R>=expand("<cword>")<CR><CR>
