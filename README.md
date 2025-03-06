# Dotfiles

This repository contains my personal dotfiles and configuration files for various tools and applications. These dotfiles help maintain a consistent development environment across different machines.

## 🗂 Contents

- Shell Configuration
  - `.bashrc` - Bash shell configuration
  - `.bash_aliases` - Custom shell aliases
  - `.bash_functions` - Custom shell functions
  - `.bash_env` - Environment variables
  - `.profile` - Login shell configuration

- Editor Configuration
  - `.vimrc` - Vim editor configuration
  - `.nanorc` - Nano editor configuration

- Git Configuration
  - `.gitconfig` - Git global configuration

- Terminal Customization
  - `.config/starship.toml` - Starship prompt configuration

- Cloud Configuration
  - `.aws/` - AWS CLI configuration directory

## 🚀 Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/beratiyilik/dotfiles.git ~/.dotfiles
   ```

2. Create symbolic links:
   ```bash
   ln -s ~/.dotfiles/.bashrc ~/.bashrc
   ln -s ~/.dotfiles/.bash_aliases ~/.bash_aliases
   ln -s ~/.dotfiles/.bash_functions ~/.bash_functions
   ln -s ~/.dotfiles/.bash_env ~/.bash_env
   ln -s ~/.dotfiles/.profile ~/.profile
   ln -s ~/.dotfiles/.vimrc ~/.vimrc
   ln -s ~/.dotfiles/.nanorc ~/.nanorc
   ln -s ~/.dotfiles/.gitconfig ~/.gitconfig
   ln -s ~/.dotfiles/.config/starship.toml ~/.config/starship.toml
   ```

## ⚙️ Features

- Customized shell prompt using Starship
- Useful shell aliases and functions
- Git configuration with helpful aliases
- Vim and Nano editor configurations
- AWS CLI configuration

## 🔧 Customization

Feel free to fork this repository and modify any of the configurations to match your preferences. The configurations are well-commented and organized for easy customization.

## 📝 Requirements

- Git
- Bash shell
- Vim (optional)
- Nano (optional)
- [Starship](https://starship.rs/) - Cross-shell prompt

## 📄 License

This project is open source and available under the MIT License.

## 👤 Author

- [@beratiyilik](https://github.com/beratiyilik)
