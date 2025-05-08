#!/bin/bash

# Security Check Script
# Version: 1.0.0
# Description: Performs various security checks and system auditing

# Determine script directory and load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Load configuration based on environment
ENV="${ENV:-prod}"  # Default to prod if not set
source "${SCRIPT_DIR}/config/config-${ENV}.sh"

# Initialize log file
readonly SECURITY_LOG="${LOG_DIR}/security-check.log"
touch "${SECURITY_LOG}" 2>/dev/null || { echo "Cannot create log file"; exit 1; }

# File integrity database
readonly INTEGRITY_DB="${SCRIPT_DIR}/data/file_hashes.db"

# Function to check for rootkits
check_rootkits() {
    print_message "${LOG_INFO}" "Starting rootkit detection" >> "${SECURITY_LOG}"
    local check_failed=0

    # Check for common rootkit files and directories
    local suspicious_paths=(
        "/dev/tcp/kthread"
        "/dev/.hist"
        "/dev/.secret"
        "/dev/..."
        "/usr/lib/libproc.so"
    )

    for path in "${suspicious_paths[@]}"; do
        if [[ -e "${path}" ]]; then
            print_message "${LOG_ERROR}" "Suspicious file/directory found: ${path}" >> "${SECURITY_LOG}"
            ((check_failed++))
        fi
    done

    # Check for hidden processes
    local visible_pids=( $(ls /proc | grep -E '^[0-9]+$') )
    local ps_pids=( $(ps -e -o pid=) )
    
    for pid in "${visible_pids[@]}"; do
        if [[ ! " ${ps_pids[@]} " =~ " ${pid} " ]]; then
            print_message "${LOG_ERROR}" "Hidden process detected: PID ${pid}" >> "${SECURITY_LOG}"
            ((check_failed++))
        fi
    done

    return ${check_failed}
}

# Function to check file integrity
check_file_integrity() {
    print_message "${LOG_INFO}" "Starting file integrity check" >> "${SECURITY_LOG}"
    local check_failed=0

    # Create integrity database if it doesn't exist
    if [[ ! -f "${INTEGRITY_DB}" ]]; then
        mkdir -p "$(dirname "${INTEGRITY_DB}")"
        touch "${INTEGRITY_DB}"
    fi

    # List of critical files to monitor
    local critical_files=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/group"
        "/etc/sudoers"
        "/etc/ssh/sshd_config"
        "/etc/hosts"
    )

    for file in "${critical_files[@]}"; do
        if [[ -f "${file}" ]]; then
            local current_hash
            current_hash=$(sha256sum "${file}" | cut -d' ' -f1)
            local stored_hash
            stored_hash=$(grep "^${file}:" "${INTEGRITY_DB}" 2>/dev/null | cut -d: -f2)

            if [[ -z "${stored_hash}" ]]; then
                # First time seeing this file, store its hash
                echo "${file}:${current_hash}" >> "${INTEGRITY_DB}"
                print_message "${LOG_INFO}" "Stored new hash for ${file}" >> "${SECURITY_LOG}"
            elif [[ "${current_hash}" != "${stored_hash}" ]]; then
                print_message "${LOG_ERROR}" "File integrity mismatch: ${file}" >> "${SECURITY_LOG}"
                ((check_failed++))
            fi
        else
            print_message "${LOG_WARNING}" "Critical file not found: ${file}" >> "${SECURITY_LOG}"
            ((check_failed++))
        fi
    done

    return ${check_failed}
}

# Function to check suspicious processes
check_processes() {
    print_message "${LOG_INFO}" "Starting process check" >> "${SECURITY_LOG}"
    local check_failed=0

    # Check for processes running from temporary directories
    if pgrep -f "/tmp/|/dev/shm/" > /dev/null; then
        print_message "${LOG_WARNING}" "Processes running from temporary directories detected" >> "${SECURITY_LOG}"
        ((check_failed++))
    fi

    # Check for processes running as root that shouldn't be
    local suspicious_root_processes=("apache2" "nginx" "mysql" "mongodb")
    for proc in "${suspicious_root_processes[@]}"; do
        if pgrep -u root "${proc}" > /dev/null; then
            print_message "${LOG_WARNING}" "Process ${proc} running as root" >> "${SECURITY_LOG}"
            ((check_failed++))
        fi
    done

    return ${check_failed}
}

# Function to check system logs for security issues
check_logs() {
    print_message "${LOG_INFO}" "Starting log analysis" >> "${SECURITY_LOG}"
    local check_failed=0

    # Check authentication failures
    local auth_failures
    auth_failures=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo 0)
    if (( auth_failures > FAILED_LOGIN_THRESHOLD )); then
        print_message "${LOG_WARNING}" "High number of authentication failures: ${auth_failures}" >> "${SECURITY_LOG}"
        ((check_failed++))
    fi

    # Check for sudo usage
    local sudo_usage
    sudo_usage=$(grep -c "sudo:" /var/log/auth.log 2>/dev/null || echo 0)
    print_message "${LOG_INFO}" "Sudo usage count: ${sudo_usage}" >> "${SECURITY_LOG}"

    return ${check_failed}
}

# Function to check file permissions
check_permissions() {
    print_message "${LOG_INFO}" "Starting permission check" >> "${SECURITY_LOG}"
    local check_failed=0

    # List of files that should be secure
    local secure_files=(
        "/etc/shadow:0:0:400"
        "/etc/ssh/ssh_host_*:0:0:600"
        "/etc/sudoers:0:0:440"
    )

    for entry in "${secure_files[@]}"; do
        IFS=: read -r file owner group perms <<< "${entry}"
        for f in ${file}; do
            if [[ -f "${f}" ]]; then
                local current_owner
                current_owner=$(stat -c "%u" "${f}")
                local current_group
                current_group=$(stat -c "%g" "${f}")
                local current_perms
                current_perms=$(stat -c "%a" "${f}")

                if [[ "${current_owner}" != "${owner}" ]] || \
                   [[ "${current_group}" != "${group}" ]] || \
                   [[ "${current_perms}" != "${perms}" ]]; then
                    print_message "${LOG_ERROR}" "Incorrect permissions on ${f}" >> "${SECURITY_LOG}"
                    ((check_failed++))
                fi
            fi
        done
    done

    return ${check_failed}
}

# Main security check function
main() {
    print_message "${LOG_INFO}" "Starting security check process" >> "${SECURITY_LOG}"

    # Check if running as root
    check_root

    local check_failed=0

    # Perform security checks
    check_rootkits || ((check_failed++))
    check_file_integrity || ((check_failed++))
    check_processes || ((check_failed++))
    check_logs || ((check_failed++))
    check_permissions || ((check_failed++))

    # Send status notification
    if (( check_failed > 0 )); then
        send_alert "Security check completed with ${check_failed} issues found" "WARNING"
    else
        send_alert "Security check completed successfully, no issues found" "INFO"
    fi

    print_message "${LOG_INFO}" "Security check completed with ${check_failed} issues" >> "${SECURITY_LOG}"
    return ${check_failed}
}

# Run main function
main
