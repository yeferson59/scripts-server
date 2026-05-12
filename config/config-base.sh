#!/bin/bash

# Base configuration for admin scripts
# Version: 1.0.0

# Fallback logger when common.sh has not been sourced yet
if ! command -v print_message >/dev/null 2>&1; then
    print_message() {
        local level="${1:-INFO}"
        shift || true
        local message="$*"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}"
    }
fi

# Logging configuration
: "${LOG_DIR:=/var/log/admin-scripts}"
: "${MAIN_LOG:=${LOG_DIR}/admin-scripts.log}"

# Backup configuration
: "${BACKUP_RETENTION_DAYS:=30}"
: "${COMPRESSION_TYPE:=gzip}"
: "${BACKUP_VERIFICATION_ENABLED:=true}"

# Monitoring thresholds
: "${CPU_WARNING_THRESHOLD:=80}"
: "${MEMORY_WARNING_THRESHOLD:=85}"
: "${DISK_WARNING_THRESHOLD:=90}"

# Security configuration
: "${FAILED_LOGIN_THRESHOLD:=5}"
: "${PASSWORD_MIN_LENGTH:=12}"
: "${PASSWORD_COMPLEXITY_REGEX:=^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$%^&*]).*$}"

# Docker configuration
: "${DOCKER_BACKUP_ENABLED:=true}"
: "${DOCKER_MONITORING_ENABLED:=true}"

# Alert configuration
: "${ALERT_EMAIL:=}"
: "${ALERT_SLACK_WEBHOOK:=}"

# Function to validate configuration
validate_config() {
    local config_errors=0
    local log_error_level="${LOG_ERROR:-ERROR}"

    # Validate directory existence
    [[ -d "${LOG_DIR}" ]] || { print_message "${log_error_level}" "Log directory ${LOG_DIR} does not exist"; config_errors=$((config_errors+1)); }

    # Validate thresholds are numbers between 0 and 100
    [[ "${CPU_WARNING_THRESHOLD}" =~ ^[0-9]+$ ]] && (( CPU_WARNING_THRESHOLD <= 100 )) || { print_message "${log_error_level}" "Invalid CPU threshold"; config_errors=$((config_errors+1)); }
    [[ "${MEMORY_WARNING_THRESHOLD}" =~ ^[0-9]+$ ]] && (( MEMORY_WARNING_THRESHOLD <= 100 )) || { print_message "${log_error_level}" "Invalid memory threshold"; config_errors=$((config_errors+1)); }
    [[ "${DISK_WARNING_THRESHOLD}" =~ ^[0-9]+$ ]] && (( DISK_WARNING_THRESHOLD <= 100 )) || { print_message "${log_error_level}" "Invalid disk threshold"; config_errors=$((config_errors+1)); }

    return ${config_errors}
}

show_help() {
    cat <<'EOF'
Base configuration utility

Usage:
  ./config/config-base.sh [options]

Options:
  -h, --help                 Show this help message
  --init                     Initialize configuration directories
  --set-env <development|production>
                             Persist selected environment
  --validate                 Validate current configuration
  --update                   Print active configuration values
EOF
}

init_config() {
    mkdir -p "${LOG_DIR}" "$(dirname "${MAIN_LOG}")" "/etc/admin-scripts"
    print_message "${LOG_INFO:-INFO}" "Configuration directories initialized"
}

set_environment() {
    local env_name="$1"
    if [[ ! "${env_name}" =~ ^(development|production)$ ]]; then
        print_message "${LOG_ERROR:-ERROR}" "Invalid environment: ${env_name}"
        return 1
    fi
    echo "ENV=${env_name}" > /etc/admin-scripts/environment.conf
    print_message "${LOG_INFO:-INFO}" "Environment set to ${env_name}"
}

print_active_config() {
    cat <<EOF
LOG_DIR=${LOG_DIR}
MAIN_LOG=${MAIN_LOG}
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS}
CPU_WARNING_THRESHOLD=${CPU_WARNING_THRESHOLD}
MEMORY_WARNING_THRESHOLD=${MEMORY_WARNING_THRESHOLD}
DISK_WARNING_THRESHOLD=${DISK_WARNING_THRESHOLD}
FAILED_LOGIN_THRESHOLD=${FAILED_LOGIN_THRESHOLD}
DOCKER_MONITORING_ENABLED=${DOCKER_MONITORING_ENABLED}
EOF
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        --init)
            init_config
            ;;
        --set-env)
            [[ -n "${2:-}" ]] || { print_message "${LOG_ERROR:-ERROR}" "Missing environment value"; return 1; }
            set_environment "${2}"
            ;;
        --validate)
            validate_config
            ;;
        --update)
            print_active_config
            ;;
        *)
            show_help
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "--set-env" ]]; then
        [[ "${EUID}" -eq 0 ]] || { print_message "${LOG_ERROR:-ERROR}" "--set-env requires root"; exit 1; }
    fi
    main "$@"
fi
