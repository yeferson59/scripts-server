#!/bin/bash

# Development environment configuration
# Version: 1.0.0

# Source base configuration
source "$(dirname "${BASH_SOURCE[0]}")/config-base.sh"

# Override base configuration for development environment
BACKUP_RETENTION_DAYS=7  # Keep backups for shorter period in dev
CPU_WARNING_THRESHOLD=90  # More lenient CPU threshold
MEMORY_WARNING_THRESHOLD=90  # More lenient memory threshold
DISK_WARNING_THRESHOLD=95  # More lenient disk threshold

# Development-specific paths
DEV_BACKUP_DIR="/var/backups/dev"
DEV_TEST_DATA_DIR="/var/test-data"

# Development-specific settings
ENABLE_DEBUG_LOGGING=true
SKIP_SECURITY_CHECKS=false
MOCK_EXTERNAL_SERVICES=true

# Development notification settings
ALERT_EMAIL="dev-team@example.com"
ALERT_SLACK_WEBHOOK="https://hooks.slack.com/services/dev-channel"

# Additional validation for development environment
validate_dev_config() {
    validate_config  # Run base validation first
    local config_errors=$?
    local log_error_level="${LOG_ERROR:-ERROR}"
    local log_warning_level="${LOG_WARNING:-WARNING}"

    # Add development-specific validation
    [[ -d "${DEV_BACKUP_DIR}" ]] || { print_message "${log_error_level}" "Dev backup directory ${DEV_BACKUP_DIR} does not exist"; config_errors=$((config_errors+1)); }
    [[ -d "${DEV_TEST_DATA_DIR}" ]] || { print_message "${log_warning_level}" "Test data directory ${DEV_TEST_DATA_DIR} does not exist"; }

    return ${config_errors}
}

setup_dev_config() {
    mkdir -p "${LOG_DIR}" "${DEV_BACKUP_DIR}" "${DEV_TEST_DATA_DIR}"
    validate_dev_config
}

show_help() {
    cat <<'EOF'
Development configuration utility

Usage:
  ./config/config-dev.sh [options]

Options:
  -h, --help   Show this help message
  --setup      Prepare and validate development configuration
EOF
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        --setup)
            setup_dev_config
            ;;
        *)
            show_help
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
