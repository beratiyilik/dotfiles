# Dotfiles

This repository contains my personal dotfiles and configuration settings for various tools and environments.

## Overview

These dotfiles are designed to provide a consistent and efficient development environment across different machines. The configuration includes settings for:

- Shell (Bash)
- Git
- Vim
- Nano
- AWS
- ESP (ESP32/ESP8266 development)
- Various other tools and utilities

## Structure

```
.
├── .aws/           # AWS configuration files
├── .config/        # Application-specific configurations
├── .bashrc         # Main bash configuration
├── .bash_aliases   # Shell aliases
├── .bash_env       # Environment variables
├── .bash_functions # Custom shell functions
├── .gitconfig      # Git configuration
├── .nanorc         # Nano editor configuration
├── .profile        # Shell profile
└── .vimrc          # Vim editor configuration
```

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/beratiyilik/dotfiles.git
   ```

2. Run the installation script (if available) or manually symlink the files:
   ```bash
   cd dotfiles
   # Symlink the files to your home directory
   ln -s ~/dotfiles/.bashrc ~/.bashrc
   ln -s ~/dotfiles/.bash_aliases ~/.bash_aliases
   ln -s ~/dotfiles/.bash_env ~/.bash_env
   ln -s ~/dotfiles/.bash_functions ~/.bash_functions
   ln -s ~/dotfiles/.gitconfig ~/.gitconfig
   ln -s ~/dotfiles/.nanorc ~/.nanorc
   ln -s ~/dotfiles/.profile ~/.profile
   ln -s ~/dotfiles/.vimrc ~/.vimrc
   ```

3. Restart your shell or run:
   ```bash
   source ~/.bashrc
   ```

## Features

### Shell Configuration
- Custom environment variables
- Useful aliases for common commands
- Custom shell functions for improved productivity
- Interactive shell features and prompt customization

### Git Configuration
- User information
- Core editor settings
- Custom aliases
- Color schemes and formatting

### Editor Settings
- Vim configuration for efficient editing
- Nano editor preferences
- Syntax highlighting and formatting rules

### Development Tools
- AWS CLI configuration
- ESP32/ESP8266 development environment setup
- Various development tool configurations

## Maintenance

To update your dotfiles:
1. Make changes to the files in this repository
2. Commit and push the changes
3. Pull the changes on other machines where you use these dotfiles

## License

This project is open source and available under the MIT License.

## Contributing

Feel free to submit issues and enhancement requests!
