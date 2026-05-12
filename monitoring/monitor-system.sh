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
MONITOR_CONFIG_FILE="/etc/admin-scripts/monitor-system.conf"
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
  --remove-config    Remove persisted monitoring configuration
  --full-stats       Generate full server specs and usage report
  --report           Run checks and print the last report lines
  --service <name>   Check status of a specific service
EOF
}

is_greater_than() {
    local left="$1"
    local right="$2"

    awk -v left="${left}" -v right="${right}" 'BEGIN {
        if (left == "" || right == "") exit 1
        exit (left > right) ? 0 : 1
    }'
}

get_cpu_usage_percent() {
    local cpu user nice system idle iowait irq softirq steal guest guest_nice
    local total_1 total_2 idle_1 idle_2 diff_total diff_idle
    local cpu_usage

    if [[ -r /proc/stat ]]; then
        read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat || return 1
        total_1=$((user + nice + system + idle + iowait + irq + softirq + steal))
        idle_1=$((idle + iowait))

        sleep 1

        read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat || return 1
        total_2=$((user + nice + system + idle + iowait + irq + softirq + steal))
        idle_2=$((idle + iowait))

        diff_total=$((total_2 - total_1))
        diff_idle=$((idle_2 - idle_1))

        if (( diff_total <= 0 )); then
            echo "0"
            return 0
        fi

        awk -v total="${diff_total}" -v idle="${diff_idle}" 'BEGIN { printf "%.2f", ((total-idle)/total)*100 }'
        return 0
    fi

    cpu_usage="$(top -bn1 2>/dev/null | awk -F'id,' '/Cpu\(s\)/ {gsub(/^[ \t]+/, "", $1); sub(/.*,/, "", $1); print 100-$1; exit}')"
    [[ -n "${cpu_usage}" ]] || return 1
    printf "%.2f" "${cpu_usage}"
}

get_memory_usage_percent() {
    local mem_total
    local mem_available
    local mem_used

    if [[ -r /proc/meminfo ]]; then
        mem_total="$(awk '/MemTotal/ {print $2; exit}' /proc/meminfo)"
        mem_available="$(awk '/MemAvailable/ {print $2; exit}' /proc/meminfo)"

        if [[ -z "${mem_available}" ]]; then
            mem_available="$(awk '/MemFree/ {free=$2} /Buffers/ {buf=$2} /^Cached:/ {cache=$2} END {print free+buf+cache}' /proc/meminfo)"
        fi

        if [[ -n "${mem_total}" ]] && [[ -n "${mem_available}" ]] && (( mem_total > 0 )); then
            mem_used=$((mem_total - mem_available))
            awk -v used="${mem_used}" -v total="${mem_total}" 'BEGIN { printf "%.2f", (used/total)*100 }'
            return 0
        fi
    fi

    if command -v free >/dev/null 2>&1; then
        free | awk '/^Mem:/ { if ($2 > 0) printf "%.2f", ($3/$2)*100; else print "0" }'
        return 0
    fi

    return 1
}

check_cpu_usage() {
    local cpu_usage
    cpu_usage="$(get_cpu_usage_percent)"
    [[ -n "${cpu_usage}" ]] || {
        print_message "${LOG_WARNING}" "Unable to determine CPU usage" >> "${MONITOR_LOG}"
        return 1
    }

    if is_greater_than "${cpu_usage}" "${CPU_WARNING_THRESHOLD}"; then
        print_message "${LOG_WARNING}" "High CPU usage: ${cpu_usage}%" >> "${MONITOR_LOG}"
        return 1
    fi
    print_message "${LOG_INFO}" "CPU usage normal: ${cpu_usage}%" >> "${MONITOR_LOG}"
    return 0
}

# Function to check memory usage
check_memory_usage() {
    local memory_usage
    memory_usage="$(get_memory_usage_percent)"
    [[ -n "${memory_usage}" ]] || {
        print_message "${LOG_WARNING}" "Unable to determine memory usage" >> "${MONITOR_LOG}"
        return 1
    }

    if is_greater_than "${memory_usage}" "${MEMORY_WARNING_THRESHOLD}"; then
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
    local issues=0
    if ! containers=$(docker ps -a --format "{{.Names}}: {{.Status}}" 2>/dev/null); then
        print_message "${LOG_WARNING}" "Unable to query Docker daemon" >> "${MONITOR_LOG}"
        return 1
    fi

    if [[ -z "${containers}" ]]; then
        print_message "${LOG_INFO}" "No Docker containers found" >> "${MONITOR_LOG}"
        return 0
    fi

    while IFS= read -r container; do
        if [[ "${container}" == *"Exited"* || "${container}" == *"Dead"* ]]; then
            print_message "${LOG_WARNING}" "Container issue: ${container}" >> "${MONITOR_LOG}"
            issues=$((issues + 1))
        else
            print_message "${LOG_INFO}" "Container OK: ${container}" >> "${MONITOR_LOG}"
        fi
    done <<< "${containers}"

    (( issues == 0 ))
}

# Function to send alerts
send_alert() {
    local message="$1"
    local level="$2"

    # Email alert
    if [[ -n "${ALERT_EMAIL}" ]]; then
        if command -v mail >/dev/null 2>&1; then
            echo "${message}" | mail -s "System Monitor Alert: ${level}" "${ALERT_EMAIL}"
        elif command -v mailx >/dev/null 2>&1; then
            echo "${message}" | mailx -s "System Monitor Alert: ${level}" "${ALERT_EMAIL}"
        elif command -v sendmail >/dev/null 2>&1; then
            {
                echo "Subject: System Monitor Alert: ${level}"
                echo "To: ${ALERT_EMAIL}"
                echo
                echo "${message}"
            } | sendmail "${ALERT_EMAIL}"
        else
            print_message "${LOG_WARNING}" "Email alert skipped: install mail/mailx/sendmail" >> "${MONITOR_LOG}"
        fi
    fi

    # Slack alert
    if [[ -n "${ALERT_SLACK_WEBHOOK}" ]]; then
        if command -v curl >/dev/null 2>&1; then
            curl -sS -X POST -H 'Content-type: application/json' \
                --data "{\"text\":\"${level}: ${message}\"}" \
                "${ALERT_SLACK_WEBHOOK}" >/dev/null || \
                print_message "${LOG_WARNING}" "Slack alert failed to send" >> "${MONITOR_LOG}"
        else
            print_message "${LOG_WARNING}" "Slack alert skipped: curl command not found" >> "${MONITOR_LOG}"
        fi
    fi
}

# Main monitoring cycle
run_monitoring_cycle() {
    local send_notifications="${1:-true}"
    print_message "${LOG_INFO}" "Starting system monitoring" >> "${MONITOR_LOG}"

    local alerts=0

    # Run checks
    check_cpu_usage || ((alerts++))
    check_memory_usage || ((alerts++))
    check_disk_usage || ((alerts++))
    check_docker_containers || ((alerts++))

    # Send alert if any checks failed
    if ((alerts > 0)) && [[ "${send_notifications}" == "true" ]]; then
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

    if mkdir -p "$(dirname "${MONITOR_CONFIG_FILE}")" 2>/dev/null && touch "${MONITOR_CONFIG_FILE}" 2>/dev/null; then
        cat > "${MONITOR_CONFIG_FILE}" <<EOF
ENV=${ENV}
CPU_WARNING_THRESHOLD=${CPU_WARNING_THRESHOLD}
MEMORY_WARNING_THRESHOLD=${MEMORY_WARNING_THRESHOLD}
DISK_WARNING_THRESHOLD=${DISK_WARNING_THRESHOLD}
DOCKER_MONITORING_ENABLED=${DOCKER_MONITORING_ENABLED}
ALERT_EMAIL=${ALERT_EMAIL}
ALERT_SLACK_WEBHOOK=${ALERT_SLACK_WEBHOOK}
EOF
        print_message "${LOG_INFO}" "Monitoring configuration saved in ${MONITOR_CONFIG_FILE}" | tee -a "${MONITOR_LOG}"
    else
        print_message "${LOG_WARNING}" "No permission to persist config in ${MONITOR_CONFIG_FILE}" | tee -a "${MONITOR_LOG}"
    fi
}

remove_monitoring_config() {
    if [[ -f "${MONITOR_CONFIG_FILE}" ]]; then
        if rm -f "${MONITOR_CONFIG_FILE}"; then
            print_message "${LOG_INFO}" "Monitoring configuration removed: ${MONITOR_CONFIG_FILE}" | tee -a "${MONITOR_LOG}"
        else
            print_message "${LOG_ERROR}" "Failed to remove monitoring configuration: ${MONITOR_CONFIG_FILE}" | tee -a "${MONITOR_LOG}"
            return 1
        fi
    else
        print_message "${LOG_WARNING}" "No monitoring configuration found at ${MONITOR_CONFIG_FILE}" | tee -a "${MONITOR_LOG}"
    fi
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
    run_monitoring_cycle false
    echo "Latest monitoring log entries:"
    tail -n 20 "${MONITOR_LOG}"
}

generate_full_stats_report() {
    local timestamp
    local report_file
    local os_name
    local kernel
    local arch
    local hostname_value
    local uptime_value
    local cpu_model
    local cpu_cores
    local load_avg
    local mem_total
    local mem_used
    local mem_free
    local swap_total
    local swap_used
    local root_disk
    local ip_addresses
    local process_count
    local tcp_listener_count
    local udp_listener_count

    timestamp="$(date '+%Y%m%d_%H%M%S')"
    report_file="${LOG_DIR}/system-full-stats-${timestamp}.log"

    mkdir -p "${LOG_DIR}"
    touch "${report_file}" || { print_message "${LOG_ERROR}" "Cannot create report file: ${report_file}"; return 1; }

    os_name="Unknown"
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os_name="${PRETTY_NAME:-${NAME:-Unknown}}"
    fi

    kernel="$(uname -r 2>/dev/null || echo "Unknown")"
    arch="$(uname -m 2>/dev/null || echo "Unknown")"
    hostname_value="$(hostname 2>/dev/null || echo "Unknown")"
    uptime_value="$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo "Unknown")"
    cpu_model="$(awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)"
    [[ -n "${cpu_model}" ]] || cpu_model="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
    [[ -n "${cpu_model}" ]] || cpu_model="Unknown"
    cpu_cores="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo "Unknown")"
    load_avg="$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null)"
    [[ -n "${load_avg}" ]] || load_avg="$(uptime 2>/dev/null | awk -F'load average:' '{gsub(/^[ \t]+/, "", $2); print $2}')"
    [[ -n "${load_avg}" ]] || load_avg="Unknown"

    if command -v free >/dev/null 2>&1; then
        mem_total="$(free -h | awk '/^Mem:/ {print $2}')"
        mem_used="$(free -h | awk '/^Mem:/ {print $3}')"
        mem_free="$(free -h | awk '/^Mem:/ {print $4}')"
        swap_total="$(free -h | awk '/^Swap:/ {print $2}')"
        swap_used="$(free -h | awk '/^Swap:/ {print $3}')"
    else
        mem_total="$(awk '/MemTotal/ {printf "%.2f GB", $2/1024/1024}' /proc/meminfo 2>/dev/null)"
        mem_used="N/A"
        mem_free="N/A"
        swap_total="$(awk '/SwapTotal/ {printf "%.2f GB", $2/1024/1024}' /proc/meminfo 2>/dev/null)"
        swap_used="N/A"
    fi

    root_disk="$(df -h / 2>/dev/null | awk 'NR==2 {print $3" usados / "$2" total ("$5")"}')"
    [[ -n "${root_disk}" ]] || root_disk="Unknown"

    if command -v hostname >/dev/null 2>&1; then
        ip_addresses="$(hostname -I 2>/dev/null | xargs)"
    fi
    if [[ -z "${ip_addresses}" ]] && command -v ip >/dev/null 2>&1; then
        ip_addresses="$(ip -o -4 addr show 2>/dev/null | awk '{print $4}' | paste -sd' ' -)"
    fi
    [[ -n "${ip_addresses}" ]] || ip_addresses="Unknown"

    process_count="$(ps -e --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    tcp_listener_count="$(ss -lnt 2>/dev/null | awk 'NR>1' | wc -l | tr -d ' ')"
    udp_listener_count="$(ss -lnu 2>/dev/null | awk 'NR>1' | wc -l | tr -d ' ')"

    {
        echo "==== Full Server Statistics Report ===="
        echo "Generated at: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        echo "== System Specifications =="
        echo "Hostname: ${hostname_value}"
        echo "OS: ${os_name}"
        echo "Kernel: ${kernel}"
        echo "Architecture: ${arch}"
        echo "CPU model: ${cpu_model}"
        echo "CPU cores: ${cpu_cores}"
        echo "Uptime: ${uptime_value}"
        echo "IP addresses: ${ip_addresses}"
        echo
        echo "== Usage Summary =="
        echo "Load average: ${load_avg}"
        echo "Memory: ${mem_used:-N/A} used / ${mem_total:-N/A} total (free: ${mem_free:-N/A})"
        echo "Swap: ${swap_used:-N/A} used / ${swap_total:-N/A} total"
        echo "Root disk: ${root_disk}"
        echo "Processes: ${process_count:-Unknown}"
        echo "Listening sockets: TCP ${tcp_listener_count:-Unknown}, UDP ${udp_listener_count:-Unknown}"
        echo
        echo "== Top CPU Processes =="
        ps -eo pid,user,comm,%cpu,%mem --sort=-%cpu 2>/dev/null | head -n 8
        echo
        echo "== Top Memory Processes =="
        ps -eo pid,user,comm,%mem,%cpu --sort=-%mem 2>/dev/null | head -n 8
        echo
        echo "== Disk Usage by Filesystem =="
        df -h 2>/dev/null
        echo
        echo "== Network Interfaces =="
        ip -brief address 2>/dev/null || ifconfig 2>/dev/null || echo "No interface tool available"
        echo
        echo "== Docker Summary =="
        if command -v docker >/dev/null 2>&1; then
            echo "Containers running: $(docker ps -q 2>/dev/null | wc -l | tr -d ' ')"
            echo "Containers total: $(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')"
            echo "Images total: $(docker images -q 2>/dev/null | wc -l | tr -d ' ')"
        else
            echo "Docker not installed"
        fi
    } > "${report_file}"

    cat "${report_file}"
    print_message "${LOG_INFO}" "Full stats report generated: ${report_file}" | tee -a "${MONITOR_LOG}"
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        --configure)
            configure_monitoring
            ;;
        --remove-config)
            remove_monitoring_config
            ;;
        --report)
            generate_report
            ;;
        --full-stats)
            generate_full_stats_report
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
