#!/bin/bash

# Production environment configuration
# Version: 1.0.0

# Source base configuration
source "$(dirname "${BASH_SOURCE[0]}")/config-base.sh"

# Override base configuration for production environment
readonly BACKUP_RETENTION_DAYS=90  # Keep backups longer in production
readonly CPU_WARNING_THRESHOLD=75  # Stricter CPU threshold
readonly MEMORY_WARNING_THRESHOLD=80  # Stricter memory threshold
readonly DISK_WARNING_THRESHOLD=85  # Stricter disk threshold

# Production-specific paths
readonly PROD_BACKUP_DIR="/var/backups/prod"
readonly PROD_DATA_DIR="/var/data"
readonly REMOTE_BACKUP_HOST="backup.example.com"
readonly REMOTE_BACKUP_PATH="/backup/main"

# Production-specific settings
readonly ENABLE_DEBUG_LOGGING=false
readonly SKIP_SECURITY_CHECKS=false
readonly BACKUP_VERIFICATION_ENABLED=true
readonly REMOTE_BACKUP_ENABLED=true

# High availability settings
readonly HA_ENABLED=true
readonly FAILOVER_THRESHOLD=300  # 5 minutes in seconds

# Production monitoring settings
readonly MONITORING_INTERVAL=60  # Check every minute
readonly ALERT_ESCALATION_TIMEOUT=1800  # 30 minutes in seconds

# Production notification settings
readonly ALERT_EMAIL="sysadmin@example.com,oncall@example.com"
readonly ALERT_SLACK_WEBHOOK="https://hooks.slack.com/services/prod-alerts"
readonly PAGERDUTY_SERVICE_KEY="YOUR_PAGERDUTY_KEY_HERE"

# Additional validation for production environment
validate_prod_config() {
    validate_config  # Run base validation first
    local config_errors=$?

    # Add production-specific validation
    [[ -d "${PROD_BACKUP_DIR}" ]] || { print_message "${LOG_ERROR}" "Production backup directory ${PROD_BACKUP_DIR} does not exist"; config_errors=$((config_errors+1)); }
    [[ -d "${PROD_DATA_DIR}" ]] || { print_message "${LOG_ERROR}" "Production data directory ${PROD_DATA_DIR} does not exist"; config_errors=$((config_errors+1)); }

    # Validate remote backup settings if enabled
    if [[ "${REMOTE_BACKUP_ENABLED}" == "true" ]]; then
        ping -c 1 "${REMOTE_BACKUP_HOST}" &>/dev/null || { print_message "${LOG_ERROR}" "Cannot reach remote backup host ${REMOTE_BACKUP_HOST}"; config_errors=$((config_errors+1)); }
    fi

    return ${config_errors}
}
