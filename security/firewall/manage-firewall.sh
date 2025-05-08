#!/bin/bash

# Automated Firewall Management Script
# Version: 1.0.0

# Configuration
LOG_DIR="/var/log/admin-scripts/security"
FIREWALL_LOG="${LOG_DIR}/firewall.log"
BLOCKED_IPS="${LOG_DIR}/blocked_ips.txt"
WHITELIST="${LOG_DIR}/whitelist.txt"

# Ensure directories exist
mkdir -p "${LOG_DIR}"
touch "${BLOCKED_IPS}" "${WHITELIST}"

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${FIREWALL_LOG}"
}

# Function to analyze auth log for attack patterns
analyze_auth_log() {
    log_message "Analyzing authentication logs for attack patterns..."
    
    # Find IPs with more than 10 failed attempts
    grep "Failed password" /var/log/auth.log | \
    awk '{print $(NF-3)}' | sort | uniq -c | \
    awk '$1 > 10 {print $2}' > /tmp/suspicious_ips.txt
    
    # Block suspicious IPs
    while read ip; do
        if ! grep -q "^${ip}$" "${WHITELIST}"; then
            if ! grep -q "^${ip}$" "${BLOCKED_IPS}"; then
                ufw deny from "${ip}" to any
                echo "${ip}" >> "${BLOCKED_IPS}"
                log_message "Blocked IP ${ip} due to multiple failed login attempts"
            fi
        fi
    done < /tmp/suspicious_ips.txt
    
    rm /tmp/suspicious_ips.txt
}

# Function to clean up old rules
cleanup_rules() {
    log_message "Cleaning up firewall rules..."
    
    # Backup current rules
    cp /etc/ufw/user.rules "/etc/ufw/user.rules.backup.$(date +%Y%m%d)"
    
    # Reset to base configuration
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential services
    ufw allow 2222/tcp  # SSH
    ufw limit 2222/tcp  # Rate limit SSH
    
    # Block common attack vectors
    for port in 23 445 1433 3389; do
        ufw deny ${port}
    done
    
    # Block known malicious networks
    for network in "218.92.0.0/24" "176.65.142.0/24" "185.164.32.0/24"; do
        ufw deny from ${network} to any
    done
    
    # Re-add currently blocked IPs
    while read ip; do
        if ! grep -q "^${ip}$" "${WHITELIST}"; then
            ufw deny from "${ip}" to any
        fi
    done < "${BLOCKED_IPS}"
    
    ufw --force enable
}

# Function to manage whitelist
manage_whitelist() {
    local action="$1"
    local ip="$2"
    
    case "${action}" in
        add)
            if ! grep -q "^${ip}$" "${WHITELIST}"; then
                echo "${ip}" >> "${WHITELIST}"
                sed -i "/${ip}/d" "${BLOCKED_IPS}"
                ufw delete deny from "${ip}" to any
                log_message "Added ${ip} to whitelist"
            fi
            ;;
        remove)
            sed -i "/${ip}/d" "${WHITELIST}"
            log_message "Removed ${ip} from whitelist"
            ;;
    esac
}

# Function to generate firewall report
generate_report() {
    log_message "Generating firewall report..."
    
    echo "Firewall Status Report - $(date)" > "${LOG_DIR}/firewall_report.txt"
    echo "=================================" >> "${LOG_DIR}/firewall_report.txt"
    
    echo -e "\nCurrent Rules:" >> "${LOG_DIR}/firewall_report.txt"
    ufw status numbered >> "${LOG_DIR}/firewall_report.txt"
    
    echo -e "\nBlocked IPs:" >> "${LOG_DIR}/firewall_report.txt"
    wc -l "${BLOCKED_IPS}" | cut -d' ' -f1 >> "${LOG_DIR}/firewall_report.txt"
    
    echo -e "\nWhitelisted IPs:" >> "${LOG_DIR}/firewall_report.txt"
    wc -l "${WHITELIST}" | cut -d' ' -f1 >> "${LOG_DIR}/firewall_report.txt"
    
    echo -e "\nRecent Blocks:" >> "${LOG_DIR}/firewall_report.txt"
    tail -n 10 "${FIREWALL_LOG}" >> "${LOG_DIR}/firewall_report.txt"
}

# Main function
main() {
    case "$1" in
        analyze)
            analyze_auth_log
            ;;
        cleanup)
            cleanup_rules
            ;;
        whitelist)
            manage_whitelist "$2" "$3"
            ;;
        report)
            generate_report
            ;;
        *)
            echo "Usage: $0 {analyze|cleanup|whitelist|report}"
            echo "  analyze  - Analyze logs and update rules"
            echo "  cleanup  - Clean up and optimize rules"
            echo "  whitelist add|remove <ip> - Manage whitelist"
            echo "  report   - Generate firewall report"
            exit 1
            ;;
    esac
}

# Run main function with arguments
main "$@"
