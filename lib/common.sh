#!/bin/bash

# Description: Common library functions for server management scripts
# Version: 1.0.0
# Author: Yeferson
# License: MIT
#
# Dependencies:
#   - bash 4.0+
#
# Usage:
#   source ./lib/common.sh
#
# Functions:
#   log_info "message"    Log informational message
#   log_error "message"   Log error message
#   log_warning "message" Log warning message
#   check_root            Check if running as root
#   trap_errors           Set error handling
#   validate_input        Validate command input
#
# Examples:
#   source ./lib/common.sh
#   log_info "Starting process"
#   check_root || exit 1
#
# Note:
#   Must be sourced, not executed directly

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This file must be sourced: source ./lib/common.sh" >&2
    exit 1
fi

if [[ -n "${COMMON_SH_LOADED:-}" ]]; then
    return 0
fi
readonly COMMON_SH_LOADED=1

readonly LOG_INFO="INFO"
readonly LOG_WARNING="WARNING"
readonly LOG_ERROR="ERROR"
readonly LOG_DEBUG="DEBUG"

LOG_LEVEL="${LOG_LEVEL:-INFO}"

set_log_level() {
    local level="${1:-INFO}"
    case "${level^^}" in
        DEBUG|INFO|WARNING|ERROR)
            LOG_LEVEL="${level^^}"
            ;;
        *)
            print_message "${LOG_ERROR}" "Invalid log level: ${level}"
            return 1
            ;;
    esac
}

_log_level_value() {
    case "$1" in
        DEBUG) echo 0 ;;
        INFO) echo 1 ;;
        WARNING) echo 2 ;;
        ERROR) echo 3 ;;
        *) echo 1 ;;
    esac
}

_should_log() {
    local message_level="${1:-INFO}"
    local current_level="${LOG_LEVEL:-INFO}"
    (( $(_log_level_value "${message_level}") >= $(_log_level_value "${current_level}") ))
}

_format_log_line() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [${level}] ${message}"
}

print_message() {
    local level="${1:-INFO}"
    shift || true
    local message="$*"
    _format_log_line "${level}" "${message}"
}

_append_to_main_log() {
    local line="$1"

    [[ -z "${MAIN_LOG:-}" ]] && return 0

    local main_log_dir
    main_log_dir="$(dirname "${MAIN_LOG}")"
    mkdir -p "${main_log_dir}" 2>/dev/null || return 0
    echo "${line}" >> "${MAIN_LOG}" 2>/dev/null || true
}

log_info() {
    _should_log "${LOG_INFO}" || return 0
    local line
    line="$(_format_log_line "${LOG_INFO}" "$*")"
    echo "${line}"
    _append_to_main_log "${line}"
}

log_warning() {
    _should_log "${LOG_WARNING}" || return 0
    local line
    line="$(_format_log_line "${LOG_WARNING}" "$*")"
    echo "${line}" >&2
    _append_to_main_log "${line}"
}

log_error() {
    _should_log "${LOG_ERROR}" || return 0
    local line
    line="$(_format_log_line "${LOG_ERROR}" "$*")"
    echo "${line}" >&2
    _append_to_main_log "${line}"
}

check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        print_message "${LOG_ERROR}" "This script must be run as root" >&2
        return 1
    fi
    return 0
}

validate_input() {
    local input="$1"
    local label="${2:-input}"
    local regex="${3:-.*}"

    if [[ -z "${input}" ]]; then
        print_message "${LOG_ERROR}" "Empty ${label} is not allowed" >&2
        return 1
    fi

    if [[ ! "${input}" =~ ${regex} ]]; then
        print_message "${LOG_ERROR}" "Invalid ${label}: ${input}" >&2
        return 1
    fi

    return 0
}

handle_error() {
    local message="${1:-An unexpected error occurred}"
    local exit_code="${2:-1}"
    log_error "${message}"
    return "${exit_code}"
}

_common_error_trap() {
    local exit_code="$1"
    local line_number="$2"
    local command="$3"
    log_error "Command failed at line ${line_number}: ${command} (exit ${exit_code})"
    exit "${exit_code}"
}

trap_errors() {
    trap '_common_error_trap "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
}

enable_error_handling() {
    set -o errexit
    set -o nounset
    set -o pipefail
    trap_errors
}

verify_dependencies() {
    local missing=0
    local dep

    for dep in "$@"; do
        if ! command -v "${dep}" >/dev/null 2>&1; then
            print_message "${LOG_ERROR}" "Missing dependency: ${dep}" >&2
            missing=$((missing + 1))
        fi
    done

    (( missing == 0 ))
}

check_system_health() {
    local errors=0
    local disk_usage=0
    local memory_usage=0

    disk_usage="$(df -P / 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5}')"
    if [[ -n "${disk_usage}" ]] && (( disk_usage > 90 )); then
        log_warning "Disk usage is high: ${disk_usage}%"
        errors=$((errors + 1))
    fi

    if command -v free >/dev/null 2>&1; then
        memory_usage="$(free | awk '/^Mem:/ {printf "%.0f", ($3/$2)*100}')"
        if [[ -n "${memory_usage}" ]] && (( memory_usage > 90 )); then
            log_warning "Memory usage is high: ${memory_usage}%"
            errors=$((errors + 1))
        fi
    fi

    return "${errors}"
}

send_alert() {
    local message="$1"
    local level="${2:-INFO}"
    local sent=0

    if [[ -n "${ALERT_EMAIL:-}" ]]; then
        if command -v mail >/dev/null 2>&1; then
            echo "${message}" | mail -s "Admin Scripts Alert: ${level}" "${ALERT_EMAIL}" && sent=1
        else
            log_warning "mail command not found. Skipping email alert."
        fi
    fi

    if [[ -n "${ALERT_SLACK_WEBHOOK:-}" ]]; then
        if command -v curl >/dev/null 2>&1; then
            curl -sS -X POST -H "Content-type: application/json" \
                --data "{\"text\":\"${level}: ${message}\"}" \
                "${ALERT_SLACK_WEBHOOK}" >/dev/null && sent=1
        else
            log_warning "curl command not found. Skipping Slack alert."
        fi
    fi

    (( sent == 1 )) || return 0
    return 0
}
