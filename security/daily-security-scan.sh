#!/bin/bash

# Daily Security Scan Script
# Version: 1.0.0

# Log file setup
LOG_DIR="/var/log/admin-scripts/security"
SCAN_LOG="${LOG_DIR}/daily-scan.log"
mkdir -p "${LOG_DIR}"

# Log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${SCAN_LOG}"
}

# Run security checks
log_message "Starting daily security scan"

# Update security tools
log_message "Updating security tools"
freshclam &>> "${SCAN_LOG}"
rkhunter --update &>> "${SCAN_LOG}"

# Run rootkit scan
log_message "Running rootkit scan"
rkhunter --check --skip-keypress --report-warnings-only &>> "${SCAN_LOG}"

# Run antivirus scan
log_message "Running antivirus scan"
clamscan --recursive --infected /etc /bin /sbin /usr/bin /usr/sbin &>> "${SCAN_LOG}"

# Check for failed login attempts
log_message "Checking authentication failures"
grep "Failed password" /var/log/auth.log | tail -n 10 &>> "${SCAN_LOG}"

# Check listening ports
log_message "Checking network ports"
ss -tulpn &>> "${SCAN_LOG}"

# Check disk usage
log_message "Checking disk usage"
df -h &>> "${SCAN_LOG}"

# Send report if there are any warnings
if grep -iE 'warning|error|fail|unsafe|invalid' "${SCAN_LOG}"; then
    # You can add email or notification commands here
    log_message "Security warnings detected - check log for details"
else
    log_message "Security scan completed - no warnings detected"
fi
