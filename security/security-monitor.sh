#!/bin/bash

# Security Monitoring Service
# Version: 1.0.0

# Source paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/admin-scripts/security"
MONITOR_LOG="${LOG_DIR}/monitor.log"
CONFIG_FILE="/etc/admin-scripts/notification.conf"

# Ensure directories exist
sudo mkdir -p "${LOG_DIR}"
sudo chown -R $USER:$USER "${LOG_DIR}"

# Source notification config if exists
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"

# Function to log messages
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} - $1" | tee -a "${MONITOR_LOG}"
}

# Function to send notifications
send_notification() {
    local subject="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log the alert
    log_message "ALERT: ${subject} - ${message}"

    # Send email if configured
    if [[ "${EMAIL_ENABLED}" == "true" && -n "${EMAIL_ADDRESS}" ]]; then
        echo "${message}" | mail -s "[Security Alert] ${subject}" "${EMAIL_ADDRESS}"
    fi

    # Send Slack notification if configured
    if [[ "${SLACK_ENABLED}" == "true" && -n "${SLACK_WEBHOOK}" ]]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 *${subject}*\n${message}\"}" \
            "${SLACK_WEBHOOK}"
    fi
}

# Function to check system security
check_security() {
    log_message "Starting security check..."

    # Check failed SSH attempts
    local failed_attempts=$(grep "Failed password" /var/log/auth.log | wc -l)
    if (( failed_attempts > 10 )); then
        send_notification "High number of failed login attempts" "Detected ${failed_attempts} failed login attempts"
    fi

    # Check disk usage
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if (( disk_usage > 90 )); then
        send_notification "High Disk Usage" "Disk usage is at ${disk_usage}%"
    fi

    # Check system load
    local load=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1)
    if (( $(echo "$load > 5" | bc -l) )); then
        send_notification "High System Load" "System load is ${load}"
    fi

    # Check for modified system files
    local modified_files=$(find /etc /bin /sbin -mtime -1 -type f)
    if [[ ! -z "${modified_files}" ]]; then
        send_notification "Modified System Files" "Recently modified system files detected"
    fi

    # Check running processes
    local suspicious_processes=$(ps aux | grep -E "suspicious|malicious" || true)
    if [[ ! -z "${suspicious_processes}" ]]; then
        send_notification "Suspicious Processes" "Detected potentially suspicious processes"
    fi

    # Check network connections
    local suspicious_connections=$(netstat -an | grep ESTABLISHED | grep -vE "127.0.0.1|:22" || true)
    if [[ ! -z "${suspicious_connections}" ]]; then
        log_message "Unusual network connections detected"
    fi

    # Log successful check
    log_message "Security check completed"
}

# Initialize log file
log_message "Security monitoring service started"

# Main monitoring loop
while true; do
    check_security
    sleep 300  # Check every 5 minutes
done
