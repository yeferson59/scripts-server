#!/bin/bash

# Base configuration for admin scripts
# Version: 1.0.0

# Logging configuration
readonly LOG_DIR="/var/log/admin-scripts"
readonly MAIN_LOG="${LOG_DIR}/admin-scripts.log"

# Backup configuration
readonly BACKUP_RETENTION_DAYS=30
readonly COMPRESSION_TYPE="gzip"
readonly BACKUP_VERIFICATION_ENABLED=true

# Monitoring thresholds
readonly CPU_WARNING_THRESHOLD=80
readonly MEMORY_WARNING_THRESHOLD=85
readonly DISK_WARNING_THRESHOLD=90

# Security configuration
readonly FAILED_LOGIN_THRESHOLD=5
readonly PASSWORD_MIN_LENGTH=12
readonly PASSWORD_COMPLEXITY_REGEX="^(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$%^&*]).*$"

# Docker configuration
readonly DOCKER_BACKUP_ENABLED=true
readonly DOCKER_MONITORING_ENABLED=true

# Alert configuration
readonly ALERT_EMAIL=""
readonly ALERT_SLACK_WEBHOOK=""

# Function to validate configuration
validate_config() {
    local config_errors=0

    # Validate directory existence
    [[ -d "${LOG_DIR}" ]] || { print_message "${LOG_ERROR}" "Log directory ${LOG_DIR} does not exist"; config_errors=$((config_errors+1)); }

    # Validate thresholds are numbers between 0 and 100
    [[ "${CPU_WARNING_THRESHOLD}" =~ ^[0-9]+$ ]] && (( CPU_WARNING_THRESHOLD <= 100 )) || { print_message "${LOG_ERROR}" "Invalid CPU threshold"; config_errors=$((config_errors+1)); }
    [[ "${MEMORY_WARNING_THRESHOLD}" =~ ^[0-9]+$ ]] && (( MEMORY_WARNING_THRESHOLD <= 100 )) || { print_message "${LOG_ERROR}" "Invalid memory threshold"; config_errors=$((config_errors+1)); }
    [[ "${DISK_WARNING_THRESHOLD}" =~ ^[0-9]+$ ]] && (( DISK_WARNING_THRESHOLD <= 100 )) || { print_message "${LOG_ERROR}" "Invalid disk threshold"; config_errors=$((config_errors+1)); }

    return ${config_errors}
}
