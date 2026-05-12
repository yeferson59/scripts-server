#!/bin/bash

# Description: Security monitoring and alert system
# Version: 1.0.0
# Author: Yeferson
# License: MIT
#
# Dependencies:
#   - common.sh
#   - auditd
#   - fail2ban
#
# Usage:
#   ./security-monitor.sh [options]
#
# Options:
#   -h, --help          Show this help message
#   --start            Start monitoring
#   --stop             Stop monitoring
#   --status          Show monitoring status
#   --configure       Configure monitoring
#   --test            Test monitoring system
#
# Examples:
#   ./security-monitor.sh --start
#   ./security-monitor.sh --status
#   ./security-monitor.sh --test
#
# Note:
#   Configure alert settings before starting

set -o errexit
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"

ENV="${ENV:-prod}"
source "${ROOT_DIR}/config/config-${ENV}.sh"

SECURITY_LOG_DIR="${LOG_DIR}/security"
MONITOR_LOG="${SECURITY_LOG_DIR}/monitor.log"
MONITOR_PID_FILE="/var/run/admin-security-monitor.pid"
MONITOR_INTERVAL="${MONITORING_INTERVAL:-300}"

mkdir -p "${SECURITY_LOG_DIR}" 2>/dev/null || true
if ! touch "${MONITOR_LOG}" 2>/dev/null; then
    SECURITY_LOG_DIR="/tmp/admin-scripts-security"
    MONITOR_LOG="${SECURITY_LOG_DIR}/monitor.log"
    MONITOR_PID_FILE="/tmp/admin-security-monitor.pid"
    mkdir -p "${SECURITY_LOG_DIR}"
    touch "${MONITOR_LOG}"
fi

show_help() {
    cat <<'EOF'
Security monitoring and alert system

Usage:
  ./security/core/security-monitor.sh [options]

Options:
  -h, --help          Show this help message
  --start             Start monitoring daemon
  --stop              Stop monitoring daemon
  --status            Show monitoring status
  --configure         Configure monitoring settings
  --setup             Alias for --configure
  --test              Run one monitoring cycle
EOF
}

log_monitor() {
    local level="$1"
    shift || true
    print_message "${level}" "$*" | tee -a "${MONITOR_LOG}"
}

is_monitor_running() {
    if [[ ! -f "${MONITOR_PID_FILE}" ]]; then
        return 1
    fi

    local pid
    pid="$(cat "${MONITOR_PID_FILE}")"
    if [[ -z "${pid}" ]]; then
        return 1
    fi

    kill -0 "${pid}" 2>/dev/null
}

run_monitor_cycle() {
    log_monitor "${LOG_INFO}" "Running security monitor cycle"

    local issues=0

    if [[ -x "${SCRIPT_DIR}/security-check.sh" ]]; then
        if ! "${SCRIPT_DIR}/security-check.sh" >> "${MONITOR_LOG}" 2>&1; then
            issues=$((issues + 1))
        fi
    else
        log_monitor "${LOG_WARNING}" "security-check.sh not found in ${SCRIPT_DIR}"
        issues=$((issues + 1))
    fi

    if [[ -x "${ROOT_DIR}/security/tools/analyze-logs.sh" ]]; then
        "${ROOT_DIR}/security/tools/analyze-logs.sh" >> "${MONITOR_LOG}" 2>&1 || issues=$((issues + 1))
    fi

    if (( issues > 0 )); then
        send_alert "Security monitor detected ${issues} issue(s). Review ${MONITOR_LOG}" "WARNING"
    fi

    log_monitor "${LOG_INFO}" "Security monitor cycle completed with ${issues} issue(s)"
    return "${issues}"
}

run_loop() {
    while true; do
        run_monitor_cycle || true
        sleep "${MONITOR_INTERVAL}"
    done
}

start_monitoring() {
    check_root

    if is_monitor_running; then
        log_monitor "${LOG_WARNING}" "Security monitor already running (PID $(cat "${MONITOR_PID_FILE}"))"
        return 0
    fi

    nohup "${SCRIPT_DIR}/security-monitor.sh" --run-loop >> "${MONITOR_LOG}" 2>&1 &
    local pid=$!
    echo "${pid}" > "${MONITOR_PID_FILE}"
    log_monitor "${LOG_INFO}" "Security monitor started (PID ${pid})"
}

stop_monitoring() {
    check_root

    if ! is_monitor_running; then
        log_monitor "${LOG_WARNING}" "Security monitor is not running"
        rm -f "${MONITOR_PID_FILE}"
        return 0
    fi

    local pid
    pid="$(cat "${MONITOR_PID_FILE}")"
    kill "${pid}"
    rm -f "${MONITOR_PID_FILE}"
    log_monitor "${LOG_INFO}" "Security monitor stopped (PID ${pid})"
}

show_status() {
    if is_monitor_running; then
        log_monitor "${LOG_INFO}" "Security monitor is running (PID $(cat "${MONITOR_PID_FILE}"))"
    else
        log_monitor "${LOG_INFO}" "Security monitor is stopped"
    fi

    if [[ -s "${MONITOR_LOG}" ]]; then
        echo "Last events:"
        tail -n 10 "${MONITOR_LOG}"
    fi
}

configure_monitoring() {
    check_root
    local config_file="/etc/admin-scripts/monitor.conf"

    mkdir -p "/etc/admin-scripts"
    cat > "${config_file}" <<EOF
MONITORING_INTERVAL=${MONITOR_INTERVAL}
ALERT_EMAIL=${ALERT_EMAIL}
ALERT_SLACK_WEBHOOK=${ALERT_SLACK_WEBHOOK}
EOF

    log_monitor "${LOG_INFO}" "Monitoring configuration saved to ${config_file}"
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        --start)
            start_monitoring
            ;;
        --stop)
            stop_monitoring
            ;;
        --status)
            show_status
            ;;
        --configure|--setup)
            configure_monitoring
            ;;
        --test)
            run_monitor_cycle
            ;;
        --run-loop)
            run_loop
            ;;
        *)
            show_help
            return 1
            ;;
    esac
}

main "$@"
