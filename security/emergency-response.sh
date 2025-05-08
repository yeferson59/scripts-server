#!/bin/bash

# Emergency Security Response Script
# Version: 1.0.0

# Configuration
LOG_DIR="/var/log/admin-scripts/security"
mkdir -p "${LOG_DIR}"
RESPONSE_LOG="${LOG_DIR}/emergency_response.log"

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${RESPONSE_LOG}"
}

# Function to implement immediate security measures
implement_security_measures() {
    log_message "Implementing emergency security measures..."

    # 1. Block all suspicious IPs
    log_message "Blocking suspicious IPs..."
    grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | \
    while read count ip; do
        if [ "$count" -gt 5 ]; then
            ufw deny from "$ip" to any
            log_message "Blocked IP $ip with $count failed attempts"
        fi
    done

    # 2. Enhance Fail2ban settings
    log_message "Updating Fail2ban configuration..."
    cat > /etc/fail2ban/jail.local << 'JAIL'
[DEFAULT]
bantime = 86400     # 24 hours
findtime = 300      # 5 minutes
maxretry = 2        # 2 attempts
banaction = ufw     # Use UFW for blocking

[sshd]
enabled = true
port = 2222
logpath = /var/log/auth.log
maxretry = 2
bantime = 86400
JAIL

    # 3. Limit system resources
    log_message "Implementing resource limits..."
    cat > /etc/security/limits.d/security.conf << 'LIMITS'
*           hard    nproc           1000
*           soft    nproc           900
*           hard    nofile          100000
*           soft    nofile          90000
LIMITS

    # 4. Update SSH security
    log_message "Enhancing SSH security..."
    sed -i 's/#MaxSessions.*/MaxSessions 2/' /etc/ssh/sshd_config
    sed -i 's/#MaxStartups.*/MaxStartups 2:30:10/' /etc/ssh/sshd_config

    # 5. Restart services
    log_message "Restarting security services..."
    systemctl restart fail2ban
    systemctl restart sshd

    # 6. Clear suspicious processes
    log_message "Checking for suspicious processes..."
    for pid in $(ps aux | awk '$3 > 50.0 {print $2}'); do
        log_message "High CPU process found: $(ps -p $pid -o pid,ppid,cmd,%cpu,%mem)"
    done

    # 7. Implement additional network security
    log_message "Implementing additional network security..."
    # Block common attack ports
    ufw deny 23    # Telnet
    ufw deny 445   # Microsoft-DS
    ufw deny 1433  # SQL Server
    ufw deny 3389  # RDP
    
    # Rate limiting
    ufw limit 2222/tcp
}

# Function to generate emergency report
generate_report() {
    log_message "Generating emergency security report..."

    # Current system status
    log_message "System load: $(uptime)"
    log_message "Memory usage: $(free -h)"
    log_message "Disk usage: $(df -h /)"

    # Security status
    log_message "Active connections: $(netstat -an | grep ESTABLISHED | wc -l)"
    log_message "Failed login attempts: $(grep "Failed password" /var/log/auth.log | wc -l)"
    log_message "Banned IPs: $(grep "Ban " /var/log/fail2ban.log | wc -l)"

    # Generate summary
    echo -e "\nSECURITY RESPONSE SUMMARY"
    echo "========================="
    echo "1. Blocked suspicious IPs"
    echo "2. Enhanced Fail2ban configuration"
    echo "3. Implemented resource limits"
    echo "4. Updated SSH security"
    echo "5. Implemented additional network security"
    echo "6. Checked for suspicious processes"
    echo -e "\nDetailed log available at: ${RESPONSE_LOG}"
}

# Main function
main() {
    log_message "Starting emergency security response..."
    implement_security_measures
    generate_report
    log_message "Emergency response completed"
}

# Run main function
main
