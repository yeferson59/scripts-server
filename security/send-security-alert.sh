#!/bin/bash

# Security Alert Script
# Version: 1.0.0

# Configuration
ADMIN_EMAIL="yefersontoloza59@gmail.com"
ALERT_LOG="/var/log/admin-scripts/security/alerts.log"

# Initialize log directory
mkdir -p "$(dirname "${ALERT_LOG}")"

# Function to send email alert
send_alert() {
    local subject="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "${timestamp} - ${subject}" >> "${ALERT_LOG}"
    echo "${message}" >> "${ALERT_LOG}"
    
    echo "${message}" | mail -s "[Server Security Alert] ${subject}" "${ADMIN_EMAIL}"
}

# Function to check security events
check_security_events() {
    # Check failed SSH attempts
    local failed_ssh=$(grep "Failed password" /var/log/auth.log | tail -n 5)
    if [[ ! -z "${failed_ssh}" ]]; then
        send_alert "Multiple Failed Login Attempts" "Recent failed login attempts:\n\n${failed_ssh}"
    fi

    # Check banned IPs
    local banned_ips=$(fail2ban-client status sshd | grep "Banned IP list")
    if [[ "${banned_ips}" != *"Banned IP list:	"* ]]; then
        send_alert "New IP Addresses Banned" "Recently banned IPs:\n\n${banned_ips}"
    fi

    # Check disk usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if (( disk_usage > 90 )); then
        send_alert "High Disk Usage" "Disk usage is at ${disk_usage}%"
    fi

    # Check system load
    local load=$(uptime | awk -F'load average:' '{print $2}')
    send_alert "System Load Alert" "Current system load: ${load}"

    # Check for modified system files
    local modified_files=$(find /etc /bin /sbin /usr/bin /usr/sbin -mtime -1 -type f)
    if [[ ! -z "${modified_files}" ]]; then
        send_alert "Modified System Files" "Recently modified system files:\n\n${modified_files}"
    fi
}

# Main execution
echo "Please enter the email address for security alerts:"
read -p "Email: " ADMIN_EMAIL

echo "Testing email configuration..."
send_alert "Test Alert" "This is a test security alert. If you receive this, the alert system is working properly."

# Set up cron job for regular checks
(crontab -l 2>/dev/null; echo "*/10 * * * * /home/admin/scripts/security/send-security-alert.sh check") | crontab -

echo "Email alerts have been configured to send to: ${ADMIN_EMAIL}"
echo "A test email has been sent. Please check your inbox."
