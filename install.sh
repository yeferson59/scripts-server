#!/bin/bash

# Description: Main installation script for server management tools
# Version: 1.0.0
# Author: Yeferson
# License: MIT
#
# Dependencies:
#   - bash 4.0+
#   - git
#   - curl
#
# Usage:
#   ./install.sh [options]
#
# Options:
#   -h, --help           Show this help message
#   --version            Show version information
#   --init              Initialize the system
#   --security-tools     Install security tools
#   --monitoring-tools   Install monitoring tools
#   --maintenance-tools  Install maintenance tools
#   --verify            Verify installation
#   --update            Update installed components
#
# Examples:
#   ./install.sh --init
#   ./install.sh --security-tools
#   ./install.sh --verify
#
# Note:
#   Requires root privileges for installation

set -o errexit
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ROOT_DIR}/lib/common.sh"
source "${ROOT_DIR}/config/config-base.sh"

show_help() {
    cat <<'EOF'
Server Management Scripts Installer

Usage:
  ./install.sh [option]

Options:
  -h, --help            Show this help message
  --version             Show version information
  --init                Initialize required directories and permissions
  --security-tools      Install security dependencies
  --monitoring-tools    Install monitoring dependencies
  --maintenance-tools   Install maintenance dependencies
  --verify              Verify installation state
  --update              Update repository and base dependencies
EOF
}

show_version() {
    echo "install.sh version 1.0.0"
}

detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    else
        return 1
    fi
}

install_packages() {
    local manager
    manager="$(detect_package_manager)" || {
        log_error "No supported package manager found (apt, dnf, yum)"
        return 1
    }

    if [[ $# -eq 0 ]]; then
        log_warning "No packages requested"
        return 0
    fi

    log_info "Installing packages with ${manager}: $*"
    case "${manager}" in
        apt)
            apt-get update
            apt-get install -y "$@"
            ;;
        dnf)
            dnf install -y "$@"
            ;;
        yum)
            yum install -y "$@"
            ;;
    esac
}

init_system() {
    check_root

    local dirs=(
        "${LOG_DIR}"
        "${LOG_DIR}/security"
        "${LOG_DIR}/security/reports"
        "/etc/admin-scripts"
    )

    local dir
    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
        log_info "Ensured directory exists: ${dir}"
    done

    chmod 750 "${LOG_DIR}" "${LOG_DIR}/security" "${LOG_DIR}/security/reports"
    chmod 750 "/etc/admin-scripts"

    log_info "Initialization completed"
}

install_security_tools() {
    check_root
    install_packages ufw fail2ban auditd rkhunter clamav
    log_info "Security tools installation completed"
}

install_monitoring_tools() {
    check_root
    install_packages bc curl mailutils procps
    log_info "Monitoring tools installation completed"
}

install_maintenance_tools() {
    check_root
    install_packages cron rsync logrotate
    log_info "Maintenance tools installation completed"
}

verify_installation() {
    local verify_errors=0
    local required_scripts=(
        "${ROOT_DIR}/security/core/secure-server.sh"
        "${ROOT_DIR}/security/core/security-monitor.sh"
        "${ROOT_DIR}/security/core/security-check.sh"
        "${ROOT_DIR}/maintenance/cleanup-system.sh"
        "${ROOT_DIR}/monitoring/monitor-system.sh"
    )
    local required_commands=(bash curl)

    if [[ ! -d "${LOG_DIR}" ]]; then
        log_error "Missing log directory: ${LOG_DIR}"
        verify_errors=$((verify_errors + 1))
    fi

    local script
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "${script}" ]]; then
            log_error "Missing script: ${script}"
            verify_errors=$((verify_errors + 1))
        fi
    done

    verify_dependencies "${required_commands[@]}" || verify_errors=$((verify_errors + 1))

    if (( verify_errors == 0 )); then
        log_info "Installation verification passed"
    else
        log_error "Installation verification failed (${verify_errors} issues)"
    fi

    return "${verify_errors}"
}

update_components() {
    check_root

    if [[ -d "${ROOT_DIR}/.git" ]]; then
        git -C "${ROOT_DIR}" pull --ff-only
        log_info "Repository updated"
    else
        log_warning "Repository metadata not found; skipping git update"
    fi

    install_packages ca-certificates curl
    log_info "Base update completed"
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        --version)
            show_version
            ;;
        --init)
            init_system
            ;;
        --security-tools)
            install_security_tools
            ;;
        --monitoring-tools)
            install_monitoring_tools
            ;;
        --maintenance-tools)
            install_maintenance_tools
            ;;
        --verify)
            verify_installation
            ;;
        --update)
            update_components
            ;;
        "")
            show_help
            return 1
            ;;
        *)
            log_error "Unknown option: ${1}"
            show_help
            return 1
            ;;
    esac
}

main "$@"
