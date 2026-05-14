set nocompatible            " disable compatibility to old-time vi
set showmatch               " show matching 
set ignorecase              " case insensitive 
set mouse=v                 " middle-click paste with 
set hlsearch                " highlight search 
set incsearch               " incremental search
set tabstop=4               " number of columns occupied by a tab 
set softtabstop=4           " see multiple spaces as tabstops so <BS> does the right thing
set expandtab               " converts tabs to white space
set shiftwidth=4            " width for autoindents
set autoindent              " indent a new line the same amount as the line just typed
set number                  " add line numbers
set wildmode=longest,list   " get bash-like tab completions
set cc=80                  " set an 80 column border for good coding style
" set foldmethod=indent
set foldnestmax=10
set nofoldenable
set foldlevel=2
filetype plugin indent on   "allow auto-indenting depending on file type
syntax on                   " syntax highlighting
set mouse=a                 " enable mouse click
if has("unnamedplus")
    set clipboard=unnamedplus
else
    set clipboard=unnamed
endif
filetype plugin on
set cursorline              " highlight current cursorline
set ttyfast                 " Speed up scrolling in Vim
" set spell                 " enable spell check (may need to download language package)
set noswapfile            " disable creating swap file
" set backupdir=~/.cache/vim " Directory to store backup files.
set encoding=UTF-8
set fileencoding=UTF-8
" set fileformat=unix
" set list
" set listchars=trail:$
let mapleader=" "


"""""""""""For vim natives""""""""""""""""""""
nnoremap <SPACE>w :w<CR>
nnoremap <SPACE>q :q<CR>
" nnoremap <C-Up> 10<C-y>
" nnoremap <C-Down> 10<C-e>
nnoremap <C-j> 10j
nnoremap <C-k> 10k
nnoremap <Leader>y "*y
nnoremap <Leader>Y "+y

" move line or visually selected block - alt+j/k
vnoremap <A-j> :m '>+1<CR>gv=gv
inoremap <A-k> <Esc>:m .-2<CR>==gi
inoremap <A-j> <Esc>:m .+1<CR>==gi
vnoremap <A-k> :m '<-2<CR>gv=gv
" move split panes to left/bottom/top/right
 nnoremap <A-h> <C-W>H
 nnoremap <A-j> <C-W>J
 nnoremap <A-k> <C-W>K
 nnoremap <A-l> <C-W>L
" move between panes to left/bottom/top/right
 nnoremap <C-Left> <C-w>h
 nnoremap <C-Down> <C-w>j
 nnoremap <C-Up> <C-w>k
 nnoremap <C-Right> <C-w>l
 " resize panels
 nnoremap <Leader><Up> 10<C-w>+
 nnoremap <Leader><Down> 10<C-w>-
nnoremap <Leader><Right> 10<C-w>>
nnoremap <Leader><Left> 10<C-w><

" Press i to enter insert mode, and ii to exit insert mode.
inoremap ii <Esc>
inoremap jk <Esc>
inoremap kj <Esc>
" vnoremap jk <Esc>
" vnoremap kj <Esc>

" Para indentar
vnoremap > >gv
vnoremap < <gv

" open file in a text by placing text and gf
nnoremap gf :vert winc f<cr>
" copies filepath to clipboard by pressing yf
nnoremap <silent> yf :let @+=expand('%:p')<CR>
" copies pwd to clipboard: command yd
nnoremap <silent> yd :let @+=expand('%:p:h')<CR>
" Vim jump to the last position when reopening a file
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
    \| exe "normal! g'\"" | endif
endif

""""For puglins
"File explorer
nnoremap dir :NERDTreeToggle <CR>
" autocmd VimEnter * NERDTree

"File finder
nnoremap <Leader>m :Files<CR>
"Word finder
nnoremap <Leader>M :Rg<CR>
" nnoremap <Leader> :Rg!<CR>
" Tabs finder
nnoremap <Leader>t :Buffers<CR>
nnoremap <Leader>a :-tabnext<CR>
nnoremap <Leader>z :+tabnext<CR>
" easy motion
nmap <Leader>s <Plug>(easymotion-s2)

nnoremap <Leader>bc :TransparentToggle<CR>

"mappings for Copilot
nnoremap <Leader>cc :CopilotChatToggle<CR>
nnoremap <Leader>cp :CopilotToggle<CR>


" Using vim-plug to configure plugins

call plug#begin()

	"File tree
	Plug 'preservim/nerdtree'

	"color scheme
	"Plug 'morhetz/gruvbox'
    "Plug 'sainnhe/gruvbox-material'
    Plug 'olimorris/onedarkpro.nvim'
    " Plug 'navarasu/onedark.nvim'
    
    " Comentary plug
    Plug 'numToStr/Comment.nvim'
	" Plug 'tpope/vim-commentary'
    
    "Surround
    Plug 'tpope/vim-surround'

    "Corchetes, keys
	Plug 'jiangmiao/auto-pairs'

	"Close tag
	Plug 'alvan/vim-closetag'

	"Tab autocomplete
	"Plug 'ervandew/supertab'

	"Status bar
	Plug 'vim-airline/vim-airline'
	Plug 'vim-airline/vim-airline-themes'

	"Files finder
	Plug 'junegunn/fzf.vim'
    Plug 'junegunn/fzf'

	"To move faster
	Plug 'easymotion/vim-easymotion'

	"Highlight syntax
	" Plug 'sheerun/vim-polyglot'	

	"Snips autocomplete
	" Plug 'SirVer/ultisnips'

	"Like a lint
	Plug 'neoclide/coc.nvim', {'branch': 'release'}

	"To search
	Plug 'eugen0329/vim-esearch'
    
    "Indent lines
    Plug 'lukas-reineke/indent-blankline.nvim'

    "Icons for files
    Plug 'ryanoasis/vim-devicons'

    Plug 'xiyaowong/transparent.nvim'

    "Copilot configuration
    Plug 'github/copilot.vim'
    Plug 'nvim-lua/plenary.nvim'
    Plug 'CopilotC-Nvim/CopilotChat.nvim'

    Plug 'nvim-lua/plenary.nvim'
    Plug 'greggh/claude-code.nvim'
    " After installing, add this to your init.vim:
    " lua require('claude-code').setup()

    "For flutter
    Plug 'nvim-flutter/flutter-tools.nvim'
    Plug 'stevearc/dressing.nvim'

    "For svelte
	Plug 'leafOfTree/vim-svelte-plugin'

call plug#end()

lua << EOF
require("CopilotChat").setup {
}
EOF

lua << EOF
  require("flutter-tools").setup {} -- use defaults
EOF

lua require('claude-code').setup()


lua require('Comment').setup()
" Color scheme configuratio
" Important!!
if has('termguicolors')
    set termguicolors
endif
" The configuration options should be placed before `colorscheme sonokai`.
" let g:gruvbox_material_better_performance = 1
" let g:gruvbox_material_foreground = 'original'
colorscheme onedark

"Staus bar configuration
" let g:airline_theme = 'bubblegum'
let g:airline_theme = 'deus'
let g:airline_powerline_fonts = 1
let laststatus=2
set noshowmode

"let g:indent_blankline_enabled = v:false


"""""""""""""""""Coc settings"""""""""""""""""""""""""""""""""""""
" Having longer updatetime (default is 4000 ms = 4s) leads to noticeable
" delays and poor user experience
set updatetime=300

" Make <CR> and <Tab> to accept selected completion item or notify coc.nvim to format
" <C-g>u breaks current undo, please make your own choice
inoremap <silent><expr> <cr> coc#pum#visible() ? coc#_select_confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" For scrolling popups
if has('nvim-0.4.3') || has('patch-8.2.0750')
          nnoremap <nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
          nnoremap <nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
          inoremap <nowait><expr> <C-f> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
          inoremap <nowait><expr> <C-b> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"
endif

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" GoTo code navigation
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

" Highlight the symbol and its references when holding the cursor
autocmd CursorHold * silent call CocActionAsync('highlight')

" Formatting selected code
xmap <leader>fw  <Plug>(coc-format-selected)
nmap <leader>fw  <Plug>(coc-format-selected)

"Formatting 
nnoremap <Leader>fa :call CocAction('format')<CR>


let g:coc_global_extensions = ['coc-json', 'coc-css', 'coc-html', 'coc-eslint', 'coc-sql', 
            \ 'coc-tsserver', 'coc-rust-analyzer', '@yaegassy/coc-intelephense', 
            \ 'coc-prettier', '@yaegassy/coc-pylsp', 'coc-snippets']
" 'coc-php-cs-fixer', 
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#_select_confirm() :
      \ coc#expandableOrJumpable() ? "\<C-r>=coc#rpc#request('doKeymap', ['snippets-expand-jump',''])\<CR>" :
      \ CheckBackspace() ? "\<TAB>" :
      \ coc#refresh()

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

let g:coc_snippet_next = '<tab>'


""""""""""""""""""""""""""""""""""""""""end coc settings""""""""""""""""""""""""""""""""""""""""



