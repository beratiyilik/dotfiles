# Dotfiles

This repository contains my personal dotfiles and configuration settings for various tools and environments. These configurations are designed to enhance productivity and provide a consistent development experience across different machines.

## Overview

This dotfiles repository includes configurations for:

- Shell environment (Zsh)
- Git
- Vim
- Nano
- AWS
- Various development tools and utilities

## Structure

```
.
├── .zshrc              # Main Zsh configuration
├── .zshenv             # Zsh environment variables
├── .zprofile           # Zsh profile settings
├── .zsh_functions      # Custom Zsh functions
├── .zsh_aliases        # Zsh aliases
├── .gitconfig          # Git configuration
├── .vimrc              # Vim configuration
├── .nanorc             # Nano configuration
├── .aws/               # AWS configuration
├── .config/            # Application configurations
└── esp/                # ESP-related configurations
```

## Features

- **Zsh Configuration**
  - Powerlevel10k theme integration
  - Custom aliases and functions
  - Environment variable management
  - Homebrew integration
  - Docker configuration
  - LLVM setup

- **Development Tools**
  - Git configuration with custom settings
  - Vim and Nano editor configurations
  - AWS CLI and SDK configurations

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/beratiyilik/dotfiles.git
   ```

2. Navigate to the dotfiles directory:
   ```bash
   cd dotfiles
   ```

3. Create symbolic links to your home directory:
   ```bash
   ln -s ~/dotfiles/.zshrc ~/.zshrc
   ln -s ~/dotfiles/.zshenv ~/.zshenv
   ln -s ~/dotfiles/.zprofile ~/.zprofile
   ln -s ~/dotfiles/.zsh_functions ~/.zsh_functions
   ln -s ~/dotfiles/.zsh_aliases ~/.zsh_aliases
   ln -s ~/dotfiles/.gitconfig ~/.gitconfig
   ln -s ~/dotfiles/.vimrc ~/.vimrc
   ln -s ~/dotfiles/.nanorc ~/.nanorc
   ```

4. Restart your shell or run:
   ```bash
   source ~/.zshrc
   ```

## Prerequisites

- macOS (tested on darwin 24.3.0)
- Zsh shell
- Homebrew package manager
- Git

## Maintenance

To update your dotfiles:

1. Make changes to the files in this repository
2. Commit and push your changes
3. Pull the changes on other machines where you use these dotfiles

## License

This project is open source and available under the MIT License.
