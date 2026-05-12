#!/bin/bash

# Description: Primary security hardening script for server configuration
# Version: 1.0.0
# Author: Yeferson
# License: MIT
#
# Dependencies:
#   - common.sh
#   - ufw
#   - fail2ban
#
# Usage:
#   ./secure-server.sh [options]
#
# Options:
#   -h, --help          Show this help message
#   --init             Initialize security configuration
#   --configure        Configure security settings
#   --audit           Perform security audit
#   --update          Update security measures
#   --status          Show security status
#
# Examples:
#   ./secure-server.sh --init
#   ./secure-server.sh --configure
#   ./secure-server.sh --status
#
# Note:
#   Requires root privileges

set -o errexit
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"

ENV="${ENV:-prod}"
source "${ROOT_DIR}/config/config-${ENV}.sh"

SECURITY_LOG_DIR="${LOG_DIR}/security"
SECURITY_LOG_FILE="${SECURITY_LOG_DIR}/secure-server.log"

mkdir -p "${SECURITY_LOG_DIR}" 2>/dev/null || true
if ! touch "${SECURITY_LOG_FILE}" 2>/dev/null; then
    SECURITY_LOG_DIR="/tmp/admin-scripts-security"
    SECURITY_LOG_FILE="${SECURITY_LOG_DIR}/secure-server.log"
    mkdir -p "${SECURITY_LOG_DIR}"
    touch "${SECURITY_LOG_FILE}"
fi

log_and_print() {
    local level="$1"
    shift || true
    local message="$*"
    print_message "${level}" "${message}" | tee -a "${SECURITY_LOG_FILE}"
}

show_help() {
    cat <<'EOF'
Primary security hardening script for server configuration

Usage:
  ./security/core/secure-server.sh [options]

Options:
  -h, --help               Show this help message
  --init                   Initialize security configuration
  --configure [basic|advanced]
                           Configure security settings (default: basic)
  --harden                 Apply full hardening (basic + advanced)
  --audit                  Perform security audit
  --update                 Update security measures
  --status                 Show security status
EOF
}

setup_log_directories() {
    mkdir -p "${LOG_DIR}" "${SECURITY_LOG_DIR}" "${SECURITY_LOG_DIR}/reports"
}

configure_ufw_basic() {
    if ! command -v ufw >/dev/null 2>&1; then
        log_and_print "${LOG_WARNING}" "ufw is not installed; skipping firewall baseline setup"
        return 0
    fi

    local ssh_port="${SSH_PORT:-22}"
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow "${ssh_port}/tcp"
    ufw limit "${ssh_port}/tcp"
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable

    log_and_print "${LOG_INFO}" "UFW baseline configured (SSH ${ssh_port}, HTTP, HTTPS)"
}

configure_fail2ban_basic() {
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        log_and_print "${LOG_WARNING}" "fail2ban is not installed; skipping basic fail2ban setup"
        return 0
    fi

    local jail_local="/etc/fail2ban/jail.local"
    if [[ ! -f "${jail_local}" ]]; then
        cat > "${jail_local}" <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable fail2ban
        systemctl restart fail2ban
    fi

    log_and_print "${LOG_INFO}" "Fail2ban baseline configured"
}

harden_sshd() {
    local sshd_config="/etc/ssh/sshd_config"

    if [[ ! -f "${sshd_config}" ]]; then
        log_and_print "${LOG_WARNING}" "sshd_config not found; skipping SSH hardening"
        return 0
    fi

    sed -i.bak -E 's/^[#[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin no/' "${sshd_config}" || true
    sed -i.bak -E 's/^[#[:space:]]*PasswordAuthentication[[:space:]]+.*/PasswordAuthentication no/' "${sshd_config}" || true
    grep -Eq '^[[:space:]]*PermitRootLogin' "${sshd_config}" || echo "PermitRootLogin no" >> "${sshd_config}"
    grep -Eq '^[[:space:]]*PasswordAuthentication' "${sshd_config}" || echo "PasswordAuthentication no" >> "${sshd_config}"

    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    fi

    log_and_print "${LOG_INFO}" "SSH hardening applied"
}

apply_advanced_hardening() {
    harden_sshd

    if command -v sysctl >/dev/null 2>&1; then
        cat > /etc/sysctl.d/99-security-hardening.conf <<'EOF'
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF
        sysctl -p /etc/sysctl.d/99-security-hardening.conf >/dev/null
        log_and_print "${LOG_INFO}" "Advanced sysctl hardening applied"
    fi
}

initialize_security() {
    check_root
    setup_log_directories
    configure_ufw_basic
    configure_fail2ban_basic
    log_and_print "${LOG_INFO}" "Security initialization completed"
}

configure_security() {
    check_root
    local profile="${1:-basic}"

    case "${profile}" in
        basic)
            configure_ufw_basic
            configure_fail2ban_basic
            ;;
        advanced)
            configure_ufw_basic
            configure_fail2ban_basic
            apply_advanced_hardening
            ;;
        *)
            log_and_print "${LOG_ERROR}" "Unsupported profile: ${profile}. Use basic or advanced."
            return 1
            ;;
    esac

    log_and_print "${LOG_INFO}" "Security configuration profile applied: ${profile}"
}

run_audit() {
    if [[ -x "${SCRIPT_DIR}/security-audit.sh" ]]; then
        "${SCRIPT_DIR}/security-audit.sh"
        log_and_print "${LOG_INFO}" "Security audit completed"
    else
        log_and_print "${LOG_ERROR}" "Audit script not found: ${SCRIPT_DIR}/security-audit.sh"
        return 1
    fi
}

update_security_measures() {
    check_root

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade openssh-server fail2ban ufw
    elif command -v dnf >/dev/null 2>&1; then
        dnf upgrade -y openssh-server fail2ban
    elif command -v yum >/dev/null 2>&1; then
        yum update -y openssh-server fail2ban
    else
        log_and_print "${LOG_ERROR}" "No supported package manager found"
        return 1
    fi

    log_and_print "${LOG_INFO}" "Security packages updated"
}

show_security_status() {
    log_and_print "${LOG_INFO}" "Security status report"

    if command -v systemctl >/dev/null 2>&1; then
        for service in ssh sshd fail2ban ufw auditd; do
            if systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
                local service_state
                service_state="$(systemctl is-active "${service}" 2>/dev/null || true)"
                print_message "${LOG_INFO}" "Service ${service}: ${service_state}" | tee -a "${SECURITY_LOG_FILE}"
            fi
        done
    fi

    if command -v ufw >/dev/null 2>&1; then
        ufw status verbose | tee -a "${SECURITY_LOG_FILE}"
    fi
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        --init)
            initialize_security
            ;;
        --configure)
            configure_security "${2:-basic}"
            ;;
        --harden)
            configure_security advanced
            ;;
        --audit)
            run_audit
            ;;
        --update)
            update_security_measures
            ;;
        --status)
            show_security_status
            ;;
        *)
            show_help
            return 1
            ;;
    esac
}

main "$@"
