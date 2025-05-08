#!/bin/bash

# GitHub Setup Script
# Version: 1.0.0
# Description: Automates the GitHub connection setup process

# Initialize log directory
LOG_DIR="/var/log/github-sync"
mkdir -p "${LOG_DIR}"
SETUP_LOG="${LOG_DIR}/setup.log"

# Logging function
log_message() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} - $1" | tee -a "${SETUP_LOG}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Git
install_git() {
    log_message "Checking Git installation..."
    
    if command_exists git; then
        log_message "Git is already installed"
        return 0
    fi

    log_message "Installing Git..."
    if command_exists apt-get; then
        sudo apt-get update && sudo apt-get install -y git
    elif command_exists yum; then
        sudo yum install -y git
    else
        log_message "ERROR: Package manager not supported"
        return 1
    fi

    if command_exists git; then
        log_message "Git installed successfully"
        return 0
    else
        log_message "ERROR: Git installation failed"
        return 1
    fi
}

# Function to configure Git
configure_git() {
    log_message "Configuring Git..."
    
    # Prompt for user information
    read -p "Enter your Git username: " git_username
    read -p "Enter your Git email: " git_email

    # Configure Git globally
    git config --global user.name "${git_username}"
    git config --global user.email "${git_email}"

    log_message "Git configured with username: ${git_username}, email: ${git_email}"
}

# Function to generate SSH key
generate_ssh_key() {
    log_message "Generating SSH key..."
    
    local ssh_dir="${HOME}/.ssh"
    local ssh_key="${ssh_dir}/id_ed25519"

    # Create .ssh directory if it doesn't exist
    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"

    # Generate SSH key if it doesn't exist
    if [[ ! -f "${ssh_key}" ]]; then
        ssh-keygen -t ed25519 -C "$(git config --global user.email)" -f "${ssh_key}" -N ""
        log_message "SSH key generated successfully"
    else
        log_message "SSH key already exists"
    fi

    # Start SSH agent and add key
    eval "$(ssh-agent -s)"
    ssh-add "${ssh_key}"

    # Display public key
    echo "==============================================="
    echo "Your SSH public key (add this to GitHub):"
    echo "==============================================="
    cat "${ssh_key}.pub"
    echo "==============================================="
    
    log_message "SSH key setup completed"
}

# Function to test GitHub connection
test_connection() {
    log_message "Testing GitHub connection..."
    
    echo "Testing connection to GitHub..."
    if ssh -T git@github.com 2>&1 | grep -q "success"; then
        log_message "Successfully connected to GitHub"
        return 0
    else
        log_message "ERROR: Failed to connect to GitHub"
        return 1
    fi
}

# Main setup function
main() {
    log_message "Starting GitHub setup process"

    # Install Git
    install_git || { log_message "Setup failed at Git installation"; exit 1; }

    # Configure Git
    configure_git || { log_message "Setup failed at Git configuration"; exit 1; }

    # Generate SSH key
    generate_ssh_key || { log_message "Setup failed at SSH key generation"; exit 1; }

    # Instructions for GitHub
    echo
    echo "Please follow these steps to add your SSH key to GitHub:"
    echo "1. Go to GitHub.com and log in"
    echo "2. Click on your profile picture → Settings"
    echo "3. Click on 'SSH and GPG keys' → 'New SSH key'"
    echo "4. Paste the SSH public key shown above"
    echo "5. Click 'Add SSH key'"
    echo
    read -p "Press Enter once you've added the key to GitHub..."

    # Test connection
    test_connection || { log_message "Setup failed at connection test"; exit 1; }

    log_message "GitHub setup completed successfully"
    echo
    echo "Setup completed successfully! You can now use GitHub with your server."
}

# Run main function
main
