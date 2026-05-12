#!/bin/bash

# System Monitoring Script
# Version: 1.0.0
# Description: Monitors system resources and Docker containers, alerts on threshold breaches

# Determine script directory and load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"

# Load configuration based on environment
ENV="${ENV:-prod}"  # Default to prod if not set
source "${ROOT_DIR}/config/config-${ENV}.sh"

# Initialize log file
MONITOR_LOG="${LOG_DIR}/system-monitor.log"
mkdir -p "${LOG_DIR}" 2>/dev/null || true
if ! touch "${MONITOR_LOG}" 2>/dev/null; then
    MONITOR_LOG="/tmp/system-monitor.log"
    touch "${MONITOR_LOG}" || { echo "Cannot create log file"; exit 1; }
fi

show_help() {
    cat <<'EOF'
System Monitoring Script

Usage:
  ./monitoring/monitor-system.sh [options]

Options:
  -h, --help         Show this help message
  --configure        Validate and prepare monitoring configuration
  --report           Run checks and print the last report lines
  --service <name>   Check status of a specific service
EOF
}

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

# Main monitoring cycle
run_monitoring_cycle() {
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

configure_monitoring() {
    mkdir -p "${LOG_DIR}"
    touch "${MONITOR_LOG}"
    if declare -F validate_config >/dev/null 2>&1; then
        validate_config
    fi
    print_message "${LOG_INFO}" "Monitoring configuration is ready" | tee -a "${MONITOR_LOG}"
}

check_service_status() {
    local service_name="$1"
    validate_input "${service_name}" "service name" '^[a-zA-Z0-9_.@-]+$'

    local status="unknown"
    if command -v systemctl >/dev/null 2>&1; then
        status="$(systemctl is-active "${service_name}" 2>/dev/null || true)"
    elif command -v service >/dev/null 2>&1; then
        status="$(service "${service_name}" status 2>/dev/null | head -n 1 || true)"
    fi

    print_message "${LOG_INFO}" "Service ${service_name}: ${status}" | tee -a "${MONITOR_LOG}"
}

generate_report() {
    run_monitoring_cycle
    echo "Latest monitoring log entries:"
    tail -n 20 "${MONITOR_LOG}"
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        --configure)
            configure_monitoring
            ;;
        --report)
            generate_report
            ;;
        --service)
            [[ -n "${2:-}" ]] || { print_message "${LOG_ERROR}" "Missing service name"; return 1; }
            check_service_status "${2}"
            ;;
        "")
            run_monitoring_cycle
            ;;
        *)
            print_message "${LOG_ERROR}" "Unknown option: ${1}"
            show_help
            return 1
            ;;
    esac
}

main "$@"
