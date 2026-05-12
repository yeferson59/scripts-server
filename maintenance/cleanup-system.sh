#!/bin/bash

# System Cleanup Script
# Version: 1.0.0
# Description: Performs system maintenance and cleanup tasks

# Determine script directory and load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${ROOT_DIR}/lib/common.sh"

# Load configuration based on environment
ENV="${ENV:-prod}"  # Default to prod if not set
source "${ROOT_DIR}/config/config-${ENV}.sh"

# Initialize log file
CLEANUP_LOG="${LOG_DIR}/system-cleanup.log"
mkdir -p "${LOG_DIR}" 2>/dev/null || true
if ! touch "${CLEANUP_LOG}" 2>/dev/null; then
    CLEANUP_LOG="/tmp/system-cleanup.log"
    touch "${CLEANUP_LOG}" || { echo "Cannot create log file"; exit 1; }
fi

show_help() {
    cat <<'EOF'
System Cleanup Script

Usage:
  ./maintenance/cleanup-system.sh [options]

Options:
  -h, --help                      Show this help message
  --manual                        Run cleanup immediately (default behavior)
  --status                        Show cleanup status and disk usage
  --schedule "<cron_expr>"        Schedule maintenance in crontab
  --configure-schedule "<expr>"   Alias for --schedule
  --set-rules <file>              Install cleanup rule file into /etc/admin-scripts
  --set-retention <days>          Override retention period for this run
  --verify                        Verify cleanup prerequisites
EOF
}

# Function to cleanup system logs
cleanup_logs() {
    print_message "${LOG_INFO}" "Starting system log cleanup" >> "${CLEANUP_LOG}"
    local cleanup_failed=0

    # Clean journal logs older than specified days
    if command -v journalctl &> /dev/null; then
        if journalctl --vacuum-time="${BACKUP_RETENTION_DAYS}days"; then
            print_message "${LOG_INFO}" "Successfully cleaned journal logs" >> "${CLEANUP_LOG}"
        else
            print_message "${LOG_ERROR}" "Failed to clean journal logs" >> "${CLEANUP_LOG}"
            ((cleanup_failed++))
        fi
    fi

    # Clean old log files in /var/log
    find /var/log -type f -name "*.log.*" -mtime "+${BACKUP_RETENTION_DAYS}" -delete 2>/dev/null || ((cleanup_failed++))
    find /var/log -type f -name "*.gz" -mtime "+${BACKUP_RETENTION_DAYS}" -delete 2>/dev/null || ((cleanup_failed++))

    return ${cleanup_failed}
}

# Function to cleanup temporary files
cleanup_temp() {
    print_message "${LOG_INFO}" "Starting temporary files cleanup" >> "${CLEANUP_LOG}"
    local cleanup_failed=0

    # Clean /tmp directory
    find /tmp -type f -atime +7 -delete 2>/dev/null || ((cleanup_failed++))
    
    # Clean user cache directories
    find /home -maxdepth 2 -type d -name ".cache" -exec find {} -type f -atime +30 -delete \; 2>/dev/null || ((cleanup_failed++))

    return ${cleanup_failed}
}

# Function to cleanup Docker resources
cleanup_docker() {
    if ! command -v docker &> /dev/null; then
        print_message "${LOG_INFO}" "Docker not installed, skipping Docker cleanup" >> "${CLEANUP_LOG}"
        return 0
    fi

    print_message "${LOG_INFO}" "Starting Docker cleanup" >> "${CLEANUP_LOG}"
    local cleanup_failed=0

    # Remove stopped containers
    if docker container prune -f > /dev/null 2>&1; then
        print_message "${LOG_INFO}" "Removed stopped containers" >> "${CLEANUP_LOG}"
    else
        print_message "${LOG_ERROR}" "Failed to remove stopped containers" >> "${CLEANUP_LOG}"
        ((cleanup_failed++))
    fi

    # Remove unused images
    if docker image prune -a -f > /dev/null 2>&1; then
        print_message "${LOG_INFO}" "Removed unused images" >> "${CLEANUP_LOG}"
    else
        print_message "${LOG_ERROR}" "Failed to remove unused images" >> "${CLEANUP_LOG}"
        ((cleanup_failed++))
    fi

    # Remove unused volumes
    if docker volume prune -f > /dev/null 2>&1; then
        print_message "${LOG_INFO}" "Removed unused volumes" >> "${CLEANUP_LOG}"
    else
        print_message "${LOG_ERROR}" "Failed to remove unused volumes" >> "${CLEANUP_LOG}"
        ((cleanup_failed++))
    fi

    # Remove unused networks
    if docker network prune -f > /dev/null 2>&1; then
        print_message "${LOG_INFO}" "Removed unused networks" >> "${CLEANUP_LOG}"
    else
        print_message "${LOG_ERROR}" "Failed to remove unused networks" >> "${CLEANUP_LOG}"
        ((cleanup_failed++))
    fi

    return ${cleanup_failed}
}

# Function to perform package cleanup
cleanup_packages() {
    print_message "${LOG_INFO}" "Starting package cleanup" >> "${CLEANUP_LOG}"
    local cleanup_failed=0

    # Detect package manager
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get clean -y && \
        apt-get autoremove -y && \
        apt-get autoclean -y || ((cleanup_failed++))
    elif command -v dnf &> /dev/null; then
        # RHEL/CentOS/Fedora
        dnf clean all && \
        dnf autoremove -y || ((cleanup_failed++))
    elif command -v yum &> /dev/null; then
        # Older RHEL/CentOS
        yum clean all && \
        yum autoremove -y || ((cleanup_failed++))
    else
        print_message "${LOG_WARNING}" "No supported package manager found" >> "${CLEANUP_LOG}"
    fi

    return ${cleanup_failed}
}

# Function to check available disk space
check_disk_space() {
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    print_message "${LOG_INFO}" "Current disk usage: ${disk_usage}%" >> "${CLEANUP_LOG}"
    
    if (( disk_usage > DISK_WARNING_THRESHOLD )); then
        return 1
    fi
    return 0
}

# Main cleanup function
run_cleanup() {
    print_message "${LOG_INFO}" "Starting system cleanup process" >> "${CLEANUP_LOG}"

    # Check if running as root
    check_root

    local cleanup_failed=0

    # Record initial disk space
    local initial_space
    initial_space=$(df -h / | awk 'NR==2 {print $4}')
    print_message "${LOG_INFO}" "Initial free space: ${initial_space}" >> "${CLEANUP_LOG}"

    # Perform cleanup tasks
    cleanup_logs || ((cleanup_failed++))
    cleanup_temp || ((cleanup_failed++))
    cleanup_docker || ((cleanup_failed++))
    cleanup_packages || ((cleanup_failed++))

    # Record final disk space
    local final_space
    final_space=$(df -h / | awk 'NR==2 {print $4}')
    print_message "${LOG_INFO}" "Final free space: ${final_space}" >> "${CLEANUP_LOG}"

    # Check final disk space status
    if ! check_disk_space; then
        print_message "${LOG_WARNING}" "Disk usage still high after cleanup" >> "${CLEANUP_LOG}"
        ((cleanup_failed++))
    fi

    # Send status notification
    if (( cleanup_failed > 0 )); then
        send_alert "System cleanup completed with ${cleanup_failed} failures" "WARNING"
    else
        send_alert "System cleanup completed successfully" "INFO"
    fi

    print_message "${LOG_INFO}" "Cleanup process completed with ${cleanup_failed} failures" >> "${CLEANUP_LOG}"
    return ${cleanup_failed}
}

show_status() {
    local disk_usage
    disk_usage="$(df -h / | awk 'NR==2 {print $5}')"

    print_message "${LOG_INFO}" "Cleanup log: ${CLEANUP_LOG}"
    print_message "${LOG_INFO}" "Retention days: ${BACKUP_RETENTION_DAYS}"
    print_message "${LOG_INFO}" "Current disk usage: ${disk_usage}"

    if [[ -f "${CLEANUP_LOG}" ]]; then
        echo "Last cleanup entries:"
        tail -n 20 "${CLEANUP_LOG}"
    fi
}

schedule_maintenance() {
    check_root
    local cron_expr="$1"
    local script_path="${SCRIPT_DIR}/cleanup-system.sh"

    validate_input "${cron_expr}" "cron expression" '.+'
    (crontab -l 2>/dev/null | grep -v "${script_path}"; echo "${cron_expr} ${script_path} --manual") | crontab -
    print_message "${LOG_INFO}" "Scheduled maintenance: ${cron_expr}" | tee -a "${CLEANUP_LOG}"
}

set_cleanup_rules() {
    check_root
    local rules_file="$1"
    local target_dir="/etc/admin-scripts"
    local target_file="${target_dir}/cleanup.rules"

    [[ -f "${rules_file}" ]] || { print_message "${LOG_ERROR}" "Rules file not found: ${rules_file}"; return 1; }
    mkdir -p "${target_dir}"
    cp "${rules_file}" "${target_file}"
    print_message "${LOG_INFO}" "Cleanup rules installed at ${target_file}" | tee -a "${CLEANUP_LOG}"
}

verify_cleanup_setup() {
    local errors=0

    command -v find >/dev/null 2>&1 || { print_message "${LOG_ERROR}" "find command is required"; errors=$((errors + 1)); }
    command -v df >/dev/null 2>&1 || { print_message "${LOG_ERROR}" "df command is required"; errors=$((errors + 1)); }
    [[ -d "${LOG_DIR}" ]] || { print_message "${LOG_ERROR}" "Missing log directory: ${LOG_DIR}"; errors=$((errors + 1)); }

    if (( errors == 0 )); then
        print_message "${LOG_INFO}" "Cleanup verification passed"
    fi

    return "${errors}"
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        --manual|"")
            run_cleanup
            ;;
        --status)
            show_status
            ;;
        --schedule|--configure-schedule)
            [[ -n "${2:-}" ]] || { print_message "${LOG_ERROR}" "Missing cron expression"; return 1; }
            schedule_maintenance "${2}"
            ;;
        --set-rules)
            [[ -n "${2:-}" ]] || { print_message "${LOG_ERROR}" "Missing rules file path"; return 1; }
            set_cleanup_rules "${2}"
            ;;
        --set-retention)
            [[ -n "${2:-}" ]] || { print_message "${LOG_ERROR}" "Missing retention days value"; return 1; }
            BACKUP_RETENTION_DAYS="${2}"
            print_message "${LOG_INFO}" "Retention updated to ${BACKUP_RETENTION_DAYS} day(s)" | tee -a "${CLEANUP_LOG}"
            ;;
        --verify)
            verify_cleanup_setup
            ;;
        *)
            print_message "${LOG_ERROR}" "Unknown option: ${1}"
            show_help
            return 1
            ;;
    esac
}

main "$@"
