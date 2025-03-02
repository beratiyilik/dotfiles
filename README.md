# Dotfiles

This repository contains my personal dotfiles and shell configurations for both Bash and Zsh shells.

## Overview

Dotfiles are configuration files used to personalize your system. This repository includes configurations for:

- **Shell environments**: Bash and Zsh configurations
- **Git**: Custom aliases and configurations
- **AWS**: Helper functions for working with AWS profiles
- **ESP-IDF**: Environment management for ESP32/ESP8266 development

## File Structure

```
├── .aws_helpers       # AWS profile management functions
├── .bash_aliases      # Bash aliases for common commands
├── .bash_env          # Bash environment variables
├── .bash_functions    # Bash utility functions
├── .bashrc            # Main Bash configuration
├── .esp_idf_helpers   # ESP-IDF environment management
├── .gitconfig         # Git configuration and aliases
├── .zsh_aliases       # Zsh aliases for common commands
├── .zsh_functions     # Zsh utility functions
├── .zshenv            # Zsh environment variables
└── .zshrc             # Main Zsh configuration
```

## Features

### Shell Configuration

- Optimized prompt configurations
- Directory navigation shortcuts
- File and directory listing enhancements
- System cleanup utilities

### Git Configuration

- Extensive set of Git aliases
- Sensible defaults for modern Git workflows
- Cross-platform compatibility

### Development Environment

- AWS profile switching and management
- ESP-IDF toolchain management for microcontroller development
- System and network utilities

## Installation

Clone this repository and create symbolic links to the files you want to use:

```bash
git clone https://github.com/beratiyilik/dotfiles.git
cd dotfiles

# For Bash users
ln -sf $(pwd)/.bashrc ~/.bashrc
ln -sf $(pwd)/.bash_aliases ~/.bash_aliases
ln -sf $(pwd)/.bash_functions ~/.bash_functions
ln -sf $(pwd)/.bash_env ~/.bash_env

# For Zsh users
ln -sf $(pwd)/.zshrc ~/.zshrc
ln -sf $(pwd)/.zshenv ~/.zshenv
ln -sf $(pwd)/.zsh_aliases ~/.zsh_aliases
ln -sf $(pwd)/.zsh_functions ~/.zsh_functions

# For Git configuration
ln -sf $(pwd)/.gitconfig ~/.gitconfig

# For AWS helpers
mkdir -p ~/.aws
ln -sf $(pwd)/.aws_helpers ~/.aws/.aws_helpers

# For ESP-IDF helpers
mkdir -p ~/esp
ln -sf $(pwd)/.esp_idf_helpers ~/esp/.esp_idf_helpers
```

## Usage

### Common Aliases

```bash
# Directory navigation
.. # Go up one level
... # Go up two levels
wd # Go to workspace directory

# File listing
la # List all files (including hidden)
ll # List detailed file information
lg "pattern" # Search for files with grep

# System utilities
kp 8080 3000 # Kill processes on specific ports
bkf file.txt # Create a backup of file with timestamp
```

### AWS Profile Management

```bash
# List all AWS profiles
awsall

# Switch to a profile (exports credentials)
awsswp profile_name

# Set a profile (only sets AWS_PROFILE)
awssp profile_name
```

### ESP-IDF Environment

```bash
# Switch to ESP32 development environment
esp32

# Switch to ESP8266 development environment
esp8266
```

## Dependencies

For full functionality, these tools are recommended:

- Git
- AWS CLI
- ESP-IDF (for microcontroller development)
- Oh My Zsh (for Zsh users)

## Customization

The configurations are designed to work across multiple platforms while being easy to customize:

- Add personal aliases in .bash_aliases or .zsh_aliases
- Add custom functions in .bash_functions or .zsh_functions
- Set personal environment variables in .bash_env or .zshenv

## License

MIT License
