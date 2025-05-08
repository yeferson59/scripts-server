#!/bin/bash

# Docker Backup Script
# Version: 1.0.0
# Description: Performs backup of Docker containers and volumes

# Determine script directory and load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Load configuration based on environment
ENV="${ENV:-prod}"  # Default to prod if not set
source "${SCRIPT_DIR}/config/config-${ENV}.sh"

# Initialize log file
readonly BACKUP_LOG="${LOG_DIR}/docker-backup.log"
touch "${BACKUP_LOG}" 2>/dev/null || { echo "Cannot create log file"; exit 1; }

# Backup timestamp
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_DIR="${PROD_BACKUP_DIR}/docker/${TIMESTAMP}"

# Function to verify backup file integrity
verify_backup() {
    local backup_file="$1"
    local verification_result=0

    if [[ "${COMPRESSION_TYPE}" == "gzip" ]]; then
        gzip -t "${backup_file}" 2>/dev/null || verification_result=1
    else
        tar tf "${backup_file}" >/dev/null 2>&1 || verification_result=1
    fi

    if (( verification_result == 0 )); then
        print_message "${LOG_INFO}" "Backup verification successful: ${backup_file}" >> "${BACKUP_LOG}"
        return 0
    else
        print_message "${LOG_ERROR}" "Backup verification failed: ${backup_file}" >> "${BACKUP_LOG}"
        return 1
    fi
}

# Function to backup Docker containers
backup_containers() {
    local containers
    containers=$(docker ps -a --format "{{.Names}}")
    local backup_failed=0

    while IFS= read -r container; do
        print_message "${LOG_INFO}" "Backing up container: ${container}" >> "${BACKUP_LOG}"
        
        local backup_file="${BACKUP_DIR}/containers/${container}.tar"
        mkdir -p "$(dirname "${backup_file}")"

        if docker export "${container}" > "${backup_file}"; then
            if [[ "${COMPRESSION_TYPE}" == "gzip" ]]; then
                gzip "${backup_file}"
                backup_file="${backup_file}.gz"
            fi

            if [[ "${BACKUP_VERIFICATION_ENABLED}" == "true" ]]; then
                verify_backup "${backup_file}" || ((backup_failed++))
            fi
        else
            print_message "${LOG_ERROR}" "Failed to backup container: ${container}" >> "${BACKUP_LOG}"
            ((backup_failed++))
        fi
    done <<< "${containers}"

    return ${backup_failed}
}

# Function to backup Docker volumes
backup_volumes() {
    local volumes
    volumes=$(docker volume ls --format "{{.Name}}")
    local backup_failed=0

    while IFS= read -r volume; do
        print_message "${LOG_INFO}" "Backing up volume: ${volume}" >> "${BACKUP_LOG}"
        
        local backup_file="${BACKUP_DIR}/volumes/${volume}.tar"
        mkdir -p "$(dirname "${backup_file}")"

        # Create a temporary container to mount the volume and backup
        if docker run --rm -v "${volume}:/source:ro" -v "$(dirname "${backup_file}"):/backup" \
            alpine tar cf "/backup/$(basename "${backup_file}")" -C /source .; then
            
            if [[ "${COMPRESSION_TYPE}" == "gzip" ]]; then
                gzip "${backup_file}"
                backup_file="${backup_file}.gz"
            fi

            if [[ "${BACKUP_VERIFICATION_ENABLED}" == "true" ]]; then
                verify_backup "${backup_file}" || ((backup_failed++))
            fi
        else
            print_message "${LOG_ERROR}" "Failed to backup volume: ${volume}" >> "${BACKUP_LOG}"
            ((backup_failed++))
        fi
    done <<< "${volumes}"

    return ${backup_failed}
}

# Function to cleanup old backups
cleanup_old_backups() {
    local backup_base_dir="${PROD_BACKUP_DIR}/docker"
    find "${backup_base_dir}" -maxdepth 1 -type d -mtime "+${BACKUP_RETENTION_DAYS}" -exec rm -rf {} \;
    print_message "${LOG_INFO}" "Cleaned up backups older than ${BACKUP_RETENTION_DAYS} days" >> "${BACKUP_LOG}"
}

# Function to sync to remote location if enabled
sync_to_remote() {
    if [[ "${REMOTE_BACKUP_ENABLED}" != "true" ]]; then
        return 0
    fi

    print_message "${LOG_INFO}" "Syncing backup to remote location" >> "${BACKUP_LOG}"
    
    if rsync -az --delete "${BACKUP_DIR}" "${REMOTE_BACKUP_HOST}:${REMOTE_BACKUP_PATH}"; then
        print_message "${LOG_INFO}" "Remote sync successful" >> "${BACKUP_LOG}"
        return 0
    else
        print_message "${LOG_ERROR}" "Remote sync failed" >> "${BACKUP_LOG}"
        return 1
    fi
}

# Main backup function
main() {
    print_message "${LOG_INFO}" "Starting Docker backup process" >> "${BACKUP_LOG}"

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_message "${LOG_ERROR}" "Docker is not running" >> "${BACKUP_LOG}"
        exit 1
    fi

    local backup_failed=0

    # Create backup directory
    mkdir -p "${BACKUP_DIR}" || { print_message "${LOG_ERROR}" "Failed to create backup directory" >> "${BACKUP_LOG}"; exit 1; }

    # Perform backups
    backup_containers || ((backup_failed++))
    backup_volumes || ((backup_failed++))

    # Sync to remote if enabled
    if [[ "${REMOTE_BACKUP_ENABLED}" == "true" ]]; then
        sync_to_remote || ((backup_failed++))
    fi

    # Cleanup old backups
    cleanup_old_backups

    # Send status notification
    if (( backup_failed > 0 )); then
        send_alert "Docker backup completed with ${backup_failed} failures" "WARNING"
    else
        send_alert "Docker backup completed successfully" "INFO"
    fi

    print_message "${LOG_INFO}" "Backup process completed with ${backup_failed} failures" >> "${BACKUP_LOG}"
    return ${backup_failed}
}

# Run main function
main
