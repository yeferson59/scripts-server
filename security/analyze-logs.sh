#!/bin/bash

# Security Log Analysis Script
# Version: 1.0.0

# Configuration
LOG_DIR="/var/log"
REPORT_DIR="/var/log/admin-scripts/security/reports"
REPORT_FILE="${REPORT_DIR}/security_analysis_$(date +%Y%m%d_%H%M%S).report"

# Ensure report directory exists
mkdir -p "${REPORT_DIR}"

# Function to write to report
write_report() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${REPORT_FILE}"
}

# Function to analyze authentication logs
analyze_auth_log() {
    write_report "=== Authentication Log Analysis ==="
    
    # Failed login attempts
    write_report "\nFailed Login Attempts (last 24 hours):"
    grep "Failed password" "${LOG_DIR}/auth.log" | tail -n 10 >> "${REPORT_FILE}"
    
    # Successful logins
    write_report "\nSuccessful Logins (last 24 hours):"
    grep "Accepted" "${LOG_DIR}/auth.log" | tail -n 10 >> "${REPORT_FILE}"
    
    # Root login attempts
    write_report "\nRoot Login Attempts:"
    grep "root" "${LOG_DIR}/auth.log" | grep -E "Failed|Accepted" | tail -n 5 >> "${REPORT_FILE}"
}

# Function to analyze fail2ban logs
analyze_fail2ban() {
    write_report "\n=== Fail2ban Analysis ==="
    
    # Current jail status
    write_report "\nCurrent Fail2ban Status:"
    fail2ban-client status >> "${REPORT_FILE}"
    
    # Recently banned IPs
    write_report "\nRecently Banned IPs:"
    grep "Ban" "${LOG_DIR}/fail2ban.log" | tail -n 10 >> "${REPORT_FILE}"
}

# Function to analyze UFW logs
analyze_ufw() {
    write_report "\n=== Firewall Log Analysis ==="
    
    # Blocked connections
    write_report "\nBlocked Connections:"
    grep "UFW BLOCK" "${LOG_DIR}/ufw.log" | tail -n 10 >> "${REPORT_FILE}"
    
    # Current UFW status
    write_report "\nCurrent Firewall Status:"
    ufw status verbose >> "${REPORT_FILE}"
}

# Function to analyze system logs
analyze_syslog() {
    write_report "\n=== System Log Analysis ==="
    
    # Error messages
    write_report "\nRecent Error Messages:"
    grep -i "error" "${LOG_DIR}/syslog" | tail -n 10 >> "${REPORT_FILE}"
    
    # Warning messages
    write_report "\nRecent Warning Messages:"
    grep -i "warning" "${LOG_DIR}/syslog" | tail -n 10 >> "${REPORT_FILE}"
}

# Function to analyze audit logs
analyze_audit() {
    write_report "\n=== Security Audit Log Analysis ==="
    
    if [[ -f "${LOG_DIR}/audit/audit.log" ]]; then
        # Authentication events
        write_report "\nAuthentication Events:"
        ausearch -m USER_LOGIN -sv no -i 2>/dev/null | tail -n 5 >> "${REPORT_FILE}"
        
        # System calls
        write_report "\nSuspicious System Calls:"
        ausearch -m SYSCALL -sv no -i 2>/dev/null | tail -n 5 >> "${REPORT_FILE}"
    fi
}

# Function to generate security summary
generate_summary() {
    write_report "\n=== Security Analysis Summary ==="
    
    # Count failed logins
    local failed_logins=$(grep "Failed password" "${LOG_DIR}/auth.log" | wc -l)
    write_report "Total failed login attempts: ${failed_logins}"
    
    # Count banned IPs
    local banned_ips=$(grep "Ban" "${LOG_DIR}/fail2ban.log" 2>/dev/null | wc -l)
    write_report "Total banned IPs: ${banned_ips}"
    
    # Check system load
    local load=$(uptime | awk -F'load average:' '{print $2}')
    write_report "Current system load:${load}"
    
    # Check disk usage
    write_report "\nDisk Usage:"
    df -h / >> "${REPORT_FILE}"
}

# Main function
main() {
    write_report "Starting security log analysis..."
    
    analyze_auth_log
    analyze_fail2ban
    analyze_ufw
    analyze_syslog
    analyze_audit
    generate_summary
    
    write_report "\nAnalysis completed. Report saved to: ${REPORT_FILE}"
    
    echo "Analysis complete. Would you like to view the report now? (y/n)"
    read -r view_report
    if [[ "${view_report}" == "y" ]]; then
        less "${REPORT_FILE}"
    fi
}

# Run main function
main
