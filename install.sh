#!/bin/bash

# Installation Script for Admin Scripts
# Version: 1.0.0
# Description: Sets up the environment for admin scripts

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common library
source "${SCRIPT_DIR}/lib/common.sh"

# Required system packages
DEBIAN_PACKAGES="logrotate rsync bc curl mailutils"
RHEL_PACKAGES="logrotate rsync bc curl mailx"

# Directory structure
readonly INSTALL_DIRS=(
    "/var/log/admin-scripts"
    "/var/backups/docker"
    "${SCRIPT_DIR}/data"
)

# Function to install system packages
install_packages() {
    print_message "${LOG_INFO}" "Installing required packages"
    local install_failed=0

    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get update && \
        apt-get install -y ${DEBIAN_PACKAGES} || install_failed=1
    elif command -v dnf &> /dev/null; then
        # RHEL/CentOS/Fedora
        dnf install -y ${RHEL_PACKAGES} || install_failed=1
    elif command -v yum &> /dev/null; then
        # Older RHEL/CentOS
        yum install -y ${RHEL_PACKAGES} || install_failed=1
    else
        print_message "${LOG_ERROR}" "No supported package manager found"
        return 1
    fi

    return ${install_failed}
}

# Function to create directory structure
create_directories() {
    print_message "${LOG_INFO}" "Creating directory structure"
    local dir_failed=0

    for dir in "${INSTALL_DIRS[@]}"; do
        if ! mkdir -p "${dir}"; then
            print_message "${LOG_ERROR}" "Failed to create directory: ${dir}"
            ((dir_failed++))
        else
            chmod 750 "${dir}"
        fi
    done

    return ${dir_failed}
}

# Function to set up cron jobs
setup_cron() {
    print_message "${LOG_INFO}" "Setting up cron jobs"
    local cron_failed=0

    # Create temporary cron file
    local temp_cron
    temp_cron=$(mktemp)

    # Export current crontab
    crontab -l > "${temp_cron}" 2>/dev/null

    # Add our jobs if they don't exist
    if ! grep -q "monitor-system.sh" "${temp_cron}"; then
        echo "*/5 * * * * ${SCRIPT_DIR}/monitor-system.sh" >> "${temp_cron}"
    fi

    if ! grep -q "backup-docker.sh" "${temp_cron}"; then
        echo "0 1 * * * ${SCRIPT_DIR}/backup-docker.sh" >> "${temp_cron}"
    fi

    if ! grep -q "cleanup-system.sh" "${temp_cron}"; then
        echo "0 3 * * * ${SCRIPT_DIR}/cleanup-system.sh" >> "${temp_cron}"
    fi

    if ! grep -q "security-check.sh" "${temp_cron}"; then
        echo "0 4 * * * ${SCRIPT_DIR}/security-check.sh" >> "${temp_cron}"
    fi

    # Install new crontab
    if ! crontab "${temp_cron}"; then
        print_message "${LOG_ERROR}" "Failed to install cron jobs"
        ((cron_failed++))
    fi

    # Cleanup
    rm -f "${temp_cron}"

    return ${cron_failed}
}

# Function to verify installation
verify_installation() {
    print_message "${LOG_INFO}" "Verifying installation"
    local verify_failed=0

    # Check directories
    for dir in "${INSTALL_DIRS[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            print_message "${LOG_ERROR}" "Directory not found: ${dir}"
            ((verify_failed++))
        fi
    done

    # Check script permissions
    local scripts=("monitor-system.sh" "backup-docker.sh" "cleanup-system.sh" "security-check.sh")
    for script in "${scripts[@]}"; do
        if [[ ! -x "${SCRIPT_DIR}/${script}" ]]; then
            print_message "${LOG_ERROR}" "Script not executable: ${script}"
            ((verify_failed++))
        fi
    done

    # Check logrotate configuration
    if [[ ! -f "/etc/logrotate.d/admin-scripts" ]]; then
        print_message "${LOG_ERROR}" "Logrotate configuration not found"
        ((verify_failed++))
    fi

    return ${verify_failed}
}

# Main installation function
main() {
    print_message "${LOG_INFO}" "Starting installation process"

    # Check if running as root
    check_root

    local install_failed=0

    # Install required packages
    install_packages || ((install_failed++))

    # Create directory structure
    create_directories || ((install_failed++))

    # Set up cron jobs
    setup_cron || ((install_failed++))

    # Verify installation
    verify_installation || ((install_failed++))

    if (( install_failed > 0 )); then
        print_message "${LOG_ERROR}" "Installation completed with ${install_failed} errors"
        return 1
    else
        print_message "${LOG_INFO}" "Installation completed successfully"
        return 0
    fi
}

# Run main function
main
