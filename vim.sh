#!/usr/bin/env sh

mkdir -p ~/.vim/.undo ~/.vim/.swap ~/.vim/.backup
mkdir -p ~/.vim/org
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# Clone plugins
cd ~/.vim/bundle

# Must have
git clone https://github.com/junegunn/fzf.git
git clone https://github.com/junegunn/fzf.vim.git
git clone https://github.com/scrooloose/nerdtree.git
git clone https://github.com/moll/vim-bbye.git
git clone https://github.com/morhetz/gruvbox.git

# Nice to have
git clone https://github.com/ludovicchabant/vim-gutentags.git
git clone https://github.com/tpope/vim-commentary.git
git clone https://github.com/tpope/vim-fugitive.git
git clone https://github.com/tpope/vim-surround.git

# Optional
git clone https://github.com/eugen0329/vim-esearch.git
git clone https://github.com/kana/vim-smartword.git
git clone https://github.com/brtastic/vim-simple-workspace.git
git clone https://github.com/brtastic/vorg.git
git clone https://github.com/brtastic/vim-jsonviewer.git