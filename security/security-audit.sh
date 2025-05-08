#!/bin/bash

# Security Audit Script
# Version: 1.0.0

# Source paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_LOG="/var/log/admin-scripts/security/audit.log"
REPORT_DIR="/var/log/admin-scripts/security/reports"

# Create necessary directories
mkdir -p "${REPORT_DIR}"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/audit_${TIMESTAMP}.report"

# Function to log audit findings
log_audit() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${AUDIT_LOG}" "${REPORT_FILE}"
}

# Function to perform system update check
check_updates() {
    log_audit "Checking for system updates..."
    apt-get update > /dev/null 2>&1
    local updates=$(apt-get -s upgrade | grep -P "^\d+ upgraded")
    log_audit "Available updates: ${updates}"
}

# Function to check user accounts
check_users() {
    log_audit "Checking user accounts..."
    # Check for users with empty passwords
    local empty_pass=$(awk -F: '($2 == "") {print}' /etc/shadow)
    if [[ ! -z "${empty_pass}" ]]; then
        log_audit "WARNING: Users with empty passwords found"
    fi
    
    # Check for users with UID 0
    local root_users=$(awk -F: '($3 == 0) {print}' /etc/passwd)
    log_audit "Users with UID 0: ${root_users}"
    
    # Check last logins
    log_audit "Recent logins:"
    last -n 5 >> "${REPORT_FILE}"
}

# Function to check file permissions
check_permissions() {
    log_audit "Checking critical file permissions..."
    local critical_files=(
        "/etc/passwd:644"
        "/etc/shadow:600"
        "/etc/sudoers:440"
    )
    
    for entry in "${critical_files[@]}"; do
        IFS=: read -r file perms <<< "${entry}"
        local current_perms=$(stat -c "%a" "${file}")
        if [[ "${current_perms}" != "${perms}" ]]; then
            log_audit "WARNING: ${file} has incorrect permissions: ${current_perms} (should be ${perms})"
        fi
    done
}

# Function to check system services
check_services() {
    log_audit "Checking critical services..."
    local critical_services=(
        "sshd"
        "ufw"
        "fail2ban"
        "auditd"
    )
    
    for service in "${critical_services[@]}"; do
        local status=$(systemctl is-active "${service}")
        log_audit "Service ${service}: ${status}"
    done
}

# Function to check network security
check_network() {
    log_audit "Checking network security..."
    
    # Check listening ports
    log_audit "Listening ports:"
    ss -tulpn >> "${REPORT_FILE}"
    
    # Check firewall status
    log_audit "Firewall status:"
    ufw status verbose >> "${REPORT_FILE}"
}

# Function to perform security scan
security_scan() {
    log_audit "Running security scan..."
    
    # Run rootkit check if available
    if command -v rkhunter > /dev/null; then
        log_audit "Running rootkit scan..."
        rkhunter --check --skip-keypress --report-warnings-only >> "${REPORT_FILE}"
    fi
    
    # Check for failed login attempts
    log_audit "Checking failed login attempts..."
    grep "Failed password" /var/log/auth.log | tail -n 5 >> "${REPORT_FILE}"
}

# Main audit function
main() {
    log_audit "Starting security audit..."
    
    # Run checks
    check_updates
    check_users
    check_permissions
    check_services
    check_network
    security_scan
    
    # Generate summary
    log_audit "Audit completed. Report saved to ${REPORT_FILE}"
    
    # Set up next audit
    if [[ "$1" == "--schedule" ]]; then
        (crontab -l 2>/dev/null; echo "0 4 * * 0 ${SCRIPT_DIR}/security-audit.sh") | crontab -
        log_audit "Scheduled weekly security audit for Sunday 4 AM"
    fi
}

# Run main function
main "$@"
