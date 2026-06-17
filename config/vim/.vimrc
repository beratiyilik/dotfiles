" Basic vim settings — no plugins, works with vanilla vim/neovim.
set nocompatible            " disable vi compatibility
syntax on
filetype plugin indent on

" Appearance
set number                  " line numbers
set ruler                   " position in the bottom-right
set showcmd
set laststatus=2            " always show the statusline
set wildmenu                " command completion menu
set background=dark
set cursorline              " highlight active line
set cursorcolumn            " highlight active column
set t_Co=256                " 256-color terminal

" Bells
set noerrorbells
set visualbell              " flash instead of beeping

" Indentation
set expandtab               " tab → space
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set smartindent

" Search
set incsearch
set hlsearch
set ignorecase
set smartcase

" Behavior
set hidden                  " switch buffers without saving
set backspace=indent,eol,start
set scrolloff=3
set encoding=utf-8
set clipboard=unnamed       " system clipboard
set modelines=0             " disable modeline (security)

" Keep temporary files in one place
set backupdir=~/.vim/backup//
set noswapfile
set undodir=~/.vim/undo//
set undofile
silent! call mkdir(expand('~/.vim/backup'), 'p')
silent! call mkdir(expand('~/.vim/undo'),   'p')

" leader = space
let mapleader = " "
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader><space> :nohlsearch<CR>