#!/bin/bash

# Production environment configuration
# Version: 1.0.0

# Source base configuration
source "$(dirname "${BASH_SOURCE[0]}")/config-base.sh"

# Override base configuration for production environment
BACKUP_RETENTION_DAYS=90  # Keep backups longer in production
CPU_WARNING_THRESHOLD=75  # Stricter CPU threshold
MEMORY_WARNING_THRESHOLD=80  # Stricter memory threshold
DISK_WARNING_THRESHOLD=85  # Stricter disk threshold

# Production-specific paths
PROD_BACKUP_DIR="/var/backups/prod"
PROD_DATA_DIR="/var/data"
REMOTE_BACKUP_HOST="backup.example.com"
REMOTE_BACKUP_PATH="/backup/main"

# Production-specific settings
ENABLE_DEBUG_LOGGING=false
SKIP_SECURITY_CHECKS=false
BACKUP_VERIFICATION_ENABLED=true
REMOTE_BACKUP_ENABLED=true

# High availability settings
HA_ENABLED=true
FAILOVER_THRESHOLD=300  # 5 minutes in seconds

# Production monitoring settings
MONITORING_INTERVAL=60  # Check every minute
ALERT_ESCALATION_TIMEOUT=1800  # 30 minutes in seconds

# Production notification settings
ALERT_EMAIL="sysadmin@example.com,oncall@example.com"
ALERT_SLACK_WEBHOOK="https://hooks.slack.com/services/prod-alerts"
PAGERDUTY_SERVICE_KEY="YOUR_PAGERDUTY_KEY_HERE"

# Additional validation for production environment
validate_prod_config() {
    validate_config  # Run base validation first
    local config_errors=$?
    local log_error_level="${LOG_ERROR:-ERROR}"

    # Add production-specific validation
    [[ -d "${PROD_BACKUP_DIR}" ]] || { print_message "${log_error_level}" "Production backup directory ${PROD_BACKUP_DIR} does not exist"; config_errors=$((config_errors+1)); }
    [[ -d "${PROD_DATA_DIR}" ]] || { print_message "${log_error_level}" "Production data directory ${PROD_DATA_DIR} does not exist"; config_errors=$((config_errors+1)); }

    # Validate remote backup settings if enabled
    if [[ "${REMOTE_BACKUP_ENABLED}" == "true" ]]; then
        ping -c 1 "${REMOTE_BACKUP_HOST}" &>/dev/null || { print_message "${log_error_level}" "Cannot reach remote backup host ${REMOTE_BACKUP_HOST}"; config_errors=$((config_errors+1)); }
    fi

    return ${config_errors}
}

setup_prod_config() {
    mkdir -p "${LOG_DIR}" "${PROD_BACKUP_DIR}" "${PROD_DATA_DIR}"
    validate_prod_config
}

show_help() {
    cat <<'EOF'
Production configuration utility

Usage:
  ./config/config-prod.sh [options]

Options:
  -h, --help   Show this help message
  --setup      Prepare and validate production configuration
EOF
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        --setup)
            setup_prod_config
            ;;
        *)
            show_help
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "--setup" ]] && [[ "${EUID}" -ne 0 ]]; then
        print_message "${LOG_ERROR:-ERROR}" "--setup requires root"
        exit 1
    fi
    main "$@"
fi
