#!/bin/bash

# Server Security Implementation Script
# Version: 1.0.0

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Initialize log file
readonly SECURITY_LOG="${LOG_DIR}/secure-server.log"
touch "${SECURITY_LOG}" 2>/dev/null || { echo "Cannot create log file"; exit 1; }

# Function to implement SSH hardening
secure_ssh() {
    log_message "${LOG_INFO}" "Configuring SSH security..."
    
    # Backup original sshd_config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Configure SSH
    sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
    sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    
    # Restart SSH service
    sudo systemctl restart sshd
}

# Function to configure firewall
configure_firewall() {
    log_message "${LOG_INFO}" "Configuring firewall..."
    
    # Install UFW if not present
    if ! command -v ufw >/dev/null 2>&1; then
        sudo apt-get install -y ufw
    fi
    
    # Configure UFW
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 2222/tcp
    sudo ufw --force enable
}

# Function to install security tools
install_security_tools() {
    log_message "${LOG_INFO}" "Installing security tools..."
    
    # Update package list
    sudo apt-get update
    
    # Install security packages
    sudo apt-get install -y \
        fail2ban \
        rkhunter \
        clamav \
        clamav-daemon \
        auditd \
        rsyslog
}

# Function to configure fail2ban
configure_fail2ban() {
    log_message "${LOG_INFO}" "Configuring fail2ban..."
    
    # Copy default config
    sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    
    # Configure fail2ban
    sudo tee /etc/fail2ban/jail.local > /dev/null << EOL
[sshd]
enabled = true
bantime = 3600
findtime = 600
maxretry = 3
EOL
    
    # Restart fail2ban
    sudo systemctl restart fail2ban
}

# Function to configure system hardening
harden_system() {
    log_message "${LOG_INFO}" "Implementing system hardening..."
    
    # Secure shared memory
    echo "tmpfs     /run/shm     tmpfs     defaults,noexec,nosuid     0     0" | sudo tee -a /etc/fstab
    
    # Configure sysctl
    cat << EOL | sudo tee /etc/sysctl.d/99-security.conf
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
EOL
    
    # Apply sysctl changes
    sudo sysctl -p
}

# Main function
main() {
    log_message "${LOG_INFO}" "Starting server security implementation"
    
    # Check if running as root
    check_root
    
    # Implement security measures
    secure_ssh
    configure_firewall
    install_security_tools
    configure_fail2ban
    harden_system
    
    log_message "${LOG_INFO}" "Security implementation completed"
    
    # Final message
    echo -e "\nSecurity implementation completed. Please review the logs at ${SECURITY_LOG}"
    echo "IMPORTANT: The SSH port has been changed to 2222. Make sure to update your connection settings."
}

# Run main function
main
