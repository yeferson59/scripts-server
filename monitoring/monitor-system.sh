#!/bin/bash

# System Monitoring Script
# Version: 1.0.0
# Description: Monitors system resources and Docker containers, alerts on threshold breaches

# Determine script directory and load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Load configuration based on environment
ENV="${ENV:-prod}"  # Default to prod if not set
source "${SCRIPT_DIR}/config/config-${ENV}.sh"

# Initialize log file
readonly MONITOR_LOG="${LOG_DIR}/system-monitor.log"
touch "${MONITOR_LOG}" 2>/dev/null || { echo "Cannot create log file"; exit 1; }

# Function to check CPU usage
check_cpu_usage() {
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    if (( $(echo "${cpu_usage} > ${CPU_WARNING_THRESHOLD}" | bc -l) )); then
        print_message "${LOG_WARNING}" "High CPU usage: ${cpu_usage}%" >> "${MONITOR_LOG}"
        return 1
    fi
    print_message "${LOG_INFO}" "CPU usage normal: ${cpu_usage}%" >> "${MONITOR_LOG}"
    return 0
}

# Function to check memory usage
check_memory_usage() {
    local memory_usage
    memory_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    if (( $(echo "${memory_usage} > ${MEMORY_WARNING_THRESHOLD}" | bc -l) )); then
        print_message "${LOG_WARNING}" "High memory usage: ${memory_usage}%" >> "${MONITOR_LOG}"
        return 1
    fi
    print_message "${LOG_INFO}" "Memory usage normal: ${memory_usage}%" >> "${MONITOR_LOG}"
    return 0
}

# Function to check disk usage
check_disk_usage() {
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if (( disk_usage > DISK_WARNING_THRESHOLD )); then
        print_message "${LOG_WARNING}" "High disk usage: ${disk_usage}%" >> "${MONITOR_LOG}"
        return 1
    fi
    print_message "${LOG_INFO}" "Disk usage normal: ${disk_usage}%" >> "${MONITOR_LOG}"
    return 0
}

# Function to check Docker containers if enabled
check_docker_containers() {
    if [[ "${DOCKER_MONITORING_ENABLED}" != "true" ]]; then
        return 0
    fi

    if ! command -v docker &> /dev/null; then
        print_message "${LOG_WARNING}" "Docker not installed but monitoring enabled" >> "${MONITOR_LOG}"
        return 1
    fi

    local containers
    containers=$(docker ps -a --format "{{.Names}}: {{.Status}}")
    while IFS= read -r container; do
        if [[ "${container}" == *"Exited"* || "${container}" == *"Dead"* ]]; then
            print_message "${LOG_WARNING}" "Container issue: ${container}" >> "${MONITOR_LOG}"
        else
            print_message "${LOG_INFO}" "Container OK: ${container}" >> "${MONITOR_LOG}"
        fi
    done <<< "${containers}"
}

# Function to send alerts
send_alert() {
    local message="$1"
    local level="$2"

    # Email alert
    if [[ -n "${ALERT_EMAIL}" ]]; then
        echo "${message}" | mail -s "System Monitor Alert: ${level}" "${ALERT_EMAIL}"
    fi

    # Slack alert
    if [[ -n "${ALERT_SLACK_WEBHOOK}" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"${level}: ${message}\"}" \
            "${ALERT_SLACK_WEBHOOK}"
    fi
}

# Main monitoring loop
main() {
    print_message "${LOG_INFO}" "Starting system monitoring" >> "${MONITOR_LOG}"

    local alerts=0

    # Run checks
    check_cpu_usage || ((alerts++))
    check_memory_usage || ((alerts++))
    check_disk_usage || ((alerts++))
    check_docker_containers || ((alerts++))

    # Send alert if any checks failed
    if ((alerts > 0)); then
        local message="System check failed with ${alerts} alerts. Check ${MONITOR_LOG} for details."
        send_alert "${message}" "WARNING"
    fi

    print_message "${LOG_INFO}" "Monitoring cycle completed with ${alerts} alerts" >> "${MONITOR_LOG}"
}

# Run main function
main
