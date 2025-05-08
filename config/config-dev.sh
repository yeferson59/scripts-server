#!/bin/bash

# Development environment configuration
# Version: 1.0.0

# Source base configuration
source "$(dirname "${BASH_SOURCE[0]}")/config-base.sh"

# Override base configuration for development environment
readonly BACKUP_RETENTION_DAYS=7  # Keep backups for shorter period in dev
readonly CPU_WARNING_THRESHOLD=90  # More lenient CPU threshold
readonly MEMORY_WARNING_THRESHOLD=90  # More lenient memory threshold
readonly DISK_WARNING_THRESHOLD=95  # More lenient disk threshold

# Development-specific paths
readonly DEV_BACKUP_DIR="/var/backups/dev"
readonly DEV_TEST_DATA_DIR="/var/test-data"

# Development-specific settings
readonly ENABLE_DEBUG_LOGGING=true
readonly SKIP_SECURITY_CHECKS=false
readonly MOCK_EXTERNAL_SERVICES=true

# Development notification settings
readonly ALERT_EMAIL="dev-team@example.com"
readonly ALERT_SLACK_WEBHOOK="https://hooks.slack.com/services/dev-channel"

# Additional validation for development environment
validate_dev_config() {
    validate_config  # Run base validation first
    local config_errors=$?

    # Add development-specific validation
    [[ -d "${DEV_BACKUP_DIR}" ]] || { print_message "${LOG_ERROR}" "Dev backup directory ${DEV_BACKUP_DIR} does not exist"; config_errors=$((config_errors+1)); }
    [[ -d "${DEV_TEST_DATA_DIR}" ]] || { print_message "${LOG_WARNING}" "Test data directory ${DEV_TEST_DATA_DIR} does not exist"; }

    return ${config_errors}
}
