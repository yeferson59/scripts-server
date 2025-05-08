#!/bin/bash

# Targeted Security Response Script
# Version: 1.0.0

# Configure logging
LOG_DIR="/var/log/admin-scripts/security"
mkdir -p "${LOG_DIR}"
RESPONSE_LOG="${LOG_DIR}/targeted_response.log"

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${RESPONSE_LOG}"
}

# Block entire suspicious networks
block_networks() {
    log_message "Blocking suspicious networks..."
    
    # Block entire subnets of major attackers
    for ip in $(grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | awk '$1 > 100 {print $2}' | cut -d. -f1-3); do
        ufw deny from ${ip}.0/24 to any
        log_message "Blocked network: ${ip}.0/24"
    done
}

# Implement strict rate limiting
implement_rate_limiting() {
    log_message "Implementing strict rate limiting..."
    
    # Rate limit SSH connections
    ufw limit 2222/tcp comment 'Rate limit SSH'
    
    # Configure sysctl for rate limiting
    cat > /etc/sysctl.d/10-security.conf << 'SYSCTL'
# Network security settings
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_timestamps = 0
SYSCTL
    sysctl -p /etc/sysctl.d/10-security.conf
}

# Configure aggressive fail2ban
configure_fail2ban() {
    log_message "Configuring aggressive fail2ban..."
    
    cat > /etc/fail2ban/jail.local << 'JAIL'
[DEFAULT]
bantime = 604800    # 1 week
findtime = 300      # 5 minutes
maxretry = 2        # 2 attempts
banaction = ufw
ignoreip = 127.0.0.1/8

[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 2
bantime = 604800
JAIL

    systemctl restart fail2ban
}

# Set up continuous monitoring
setup_monitoring() {
    log_message "Setting up continuous monitoring..."
    
    # Create monitoring script
    cat > /usr/local/bin/security-monitor.sh << 'MONITOR'
#!/bin/bash
LOG_DIR="/var/log/admin-scripts/security"
ALERT_LOG="${LOG_DIR}/alerts.log"

while true; do
    # Check for new attack patterns
    tail -f /var/log/auth.log | while read line; do
        if echo "$line" | grep -q "Failed password"; then
            echo "[$(date)] Attack detected: $line" >> "${ALERT_LOG}"
            ip=$(echo "$line" | awk '{print $(NF-3)}')
            ufw deny from $ip to any
        fi
    done
done
MONITOR

    chmod +x /usr/local/bin/security-monitor.sh
    
    # Create systemd service
    cat > /etc/systemd/system/security-monitor.service << 'SERVICE'
[Unit]
Description=Security Monitoring Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/security-monitor.sh
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

    systemctl daemon-reload
    systemctl enable security-monitor.service
    systemctl start security-monitor.service
}

# Main function
main() {
    log_message "Starting targeted security response..."
    block_networks
    implement_rate_limiting
    configure_fail2ban
    setup_monitoring
    log_message "Targeted security response completed"
}

# Run main function
main
