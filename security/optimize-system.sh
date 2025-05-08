#!/bin/bash

# System Optimization and Security Analysis Script
LOG_DIR="/var/log/admin-scripts/security"
REPORT_FILE="${LOG_DIR}/optimization_report_$(date +%Y%m%d_%H%M%S).log"

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${REPORT_FILE}"
}

# Analyze and optimize system load
optimize_system_load() {
    log_message "Analyzing system load..."
    
    # Find high CPU processes
    log_message "Top CPU-consuming processes:"
    ps aux --sort=-%cpu | head -n 6 | tee -a "${REPORT_FILE}"
    
    # Kill any runaway processes (using > 80% CPU)
    for pid in $(ps aux | awk '$3 > 80 {print $2}'); do
        log_message "Terminating high-CPU process: $(ps -p $pid -o pid,ppid,cmd,%cpu,%mem)"
        kill -15 $pid
    done
    
    # Optimize system limits
    cat > /etc/sysctl.d/99-system-limits.conf << 'LIMITS'
# System limits optimization
fs.file-max = 100000
kernel.pid_max = 65536
kernel.threads-max = 100000
vm.swappiness = 10
net.core.somaxconn = 65536
net.ipv4.tcp_max_syn_backlog = 65536
LIMITS
    sysctl -p /etc/sysctl.d/99-system-limits.conf
}

# Analyze and secure network connections
secure_network() {
    log_message "Analyzing network connections..."
    
    # List all established connections
    log_message "Current established connections:"
    netstat -antup | grep ESTABLISHED | tee -a "${REPORT_FILE}"
    
    # Block suspicious ports
    for port in 23 135 137 138 139 445 3389 5900; do
        ufw deny $port
        log_message "Blocked suspicious port: $port"
    done
    
    # Rate limit all incoming connections
    ufw limit 22/tcp
    ufw limit 80/tcp
    ufw limit 443/tcp
}

# Clean up system
cleanup_system() {
    log_message "Performing system cleanup..."
    
    # Clear temp files
    find /tmp -type f -atime +7 -delete
    
    # Clear old logs
    find /var/log -type f -name "*.gz" -delete
    find /var/log -type f -name "*.1" -delete
    
    # Clear journal logs
    journalctl --vacuum-time=2d
}

# Generate security report
generate_report() {
    log_message "Generating security report..."
    
    # System information
    log_message "System Information:"
    uname -a >> "${REPORT_FILE}"
    uptime >> "${REPORT_FILE}"
    
    # Resource usage
    log_message "Resource Usage:"
    free -h >> "${REPORT_FILE}"
    df -h >> "${REPORT_FILE}"
    
    # Network status
    log_message "Network Status:"
    netstat -s | grep -E "failed|drop|reset" >> "${REPORT_FILE}"
    
    # Security status
    log_message "Security Status:"
    fail2ban-client status >> "${REPORT_FILE}"
    ufw status numbered >> "${REPORT_FILE}"
}

# Main function
main() {
    log_message "Starting system optimization and security analysis..."
    optimize_system_load
    secure_network
    cleanup_system
    generate_report
    log_message "Optimization and analysis completed. Report saved to: ${REPORT_FILE}"
}

# Run main function
main
