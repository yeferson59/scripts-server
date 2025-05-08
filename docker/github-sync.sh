#!/bin/bash

# GitHub Sync Script
# Version: 1.0.0
# Description: Automates GitHub repository synchronization

# Initialize log directory
LOG_DIR="/var/log/github-sync"
mkdir -p "${LOG_DIR}"
SYNC_LOG="${LOG_DIR}/sync.log"

# Default values
DEFAULT_BRANCH="main"
SYNC_INTERVAL=300  # 5 minutes in seconds

# Logging function
log_message() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} - $1" | tee -a "${SYNC_LOG}"
}

# Function to check if directory is a git repository
is_git_repo() {
    git rev-parse --git-dir > /dev/null 2>&1
}

# Function to check for uncommitted changes
has_local_changes() {
    git status --porcelain | grep -q "."
}

# Function to fetch and check for remote changes
has_remote_changes() {
    git fetch origin
    local LOCAL=$(git rev-parse @)
    local REMOTE=$(git rev-parse @{u})
    local BASE=$(git merge-base @ @{u})

    if [[ "${LOCAL}" == "${REMOTE}" ]]; then
        return 1  # No changes
    else
        return 0  # Has changes
    fi
}

# Function to handle merge conflicts
handle_conflicts() {
    if git status | grep -q "both modified"; then
        log_message "WARN: Merge conflicts detected"
        
        # Create conflict branch
        local conflict_branch="conflict-$(date +%Y%m%d-%H%M%S)"
        git checkout -b "${conflict_branch}"
        
        log_message "Created conflict branch: ${conflict_branch}"
        echo "Please resolve conflicts in branch: ${conflict_branch}"
        return 1
    fi
    return 0
}

# Function to pull changes
pull_changes() {
    log_message "Pulling changes from remote..."
    
    if git pull origin "${BRANCH}"; then
        log_message "Successfully pulled changes"
        return 0
    else
        log_message "ERROR: Failed to pull changes"
        return 1
    fi
}

# Function to push changes
push_changes() {
    local commit_message="$1"
    
    log_message "Pushing changes to remote..."
    
    # Add all changes
    git add -A

    # Commit changes if there are any
    if has_local_changes; then
        if git commit -m "${commit_message}"; then
            if git push origin "${BRANCH}"; then
                log_message "Successfully pushed changes"
                return 0
            else
                log_message "ERROR: Failed to push changes"
                return 1
            fi
        else
            log_message "ERROR: Failed to commit changes"
            return 1
        fi
    else
        log_message "No changes to push"
        return 0
    fi
}

# Function to sync repository
sync_repo() {
    local repo_path="$1"
    local commit_message="$2"

    # Change to repository directory
    cd "${repo_path}" || { log_message "ERROR: Cannot change to directory ${repo_path}"; return 1; }

    # Verify it's a git repository
    if ! is_git_repo; then
        log_message "ERROR: Not a git repository: ${repo_path}"
        return 1
    fi

    # Get current branch
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    [[ -z "${BRANCH}" ]] && BRANCH="${DEFAULT_BRANCH}"

    log_message "Starting sync for repository: ${repo_path} (${BRANCH})"

    # Check for remote changes
    if has_remote_changes; then
        log_message "Remote changes detected"
        
        # Stash local changes if any
        if has_local_changes; then
            log_message "Stashing local changes"
            git stash
        fi

        # Pull changes
        if ! pull_changes; then
            if ! handle_conflicts; then
                return 1
            fi
        fi

        # Apply stashed changes if any
        if git stash list | grep -q .; then
            log_message "Applying stashed changes"
            git stash pop
        fi
    fi

    # Push local changes
    if has_local_changes; then
        push_changes "${commit_message}" || return 1
    fi

    log_message "Sync completed successfully"
    return 0
}

# Function to display usage
usage() {
    echo "Usage: $0 [-d directory] [-m message] [-b branch] [-i interval]"
    echo "  -d: Repository directory (default: current directory)"
    echo "  -m: Commit message (default: Automated sync YYYY-MM-DD HH:MM)"
    echo "  -b: Branch to sync (default: main)"
    echo "  -i: Sync interval in seconds (default: 300, 0 for single sync)"
    exit 1
}

# Main function
main() {
    local REPO_DIR="."
    local COMMIT_MESSAGE="Automated sync $(date '+%Y-%m-%d %H:%M')"
    local INTERVAL="${SYNC_INTERVAL}"

    # Parse command line arguments
    while getopts "d:m:b:i:h" opt; do
        case "${opt}" in
            d) REPO_DIR="${OPTARG}" ;;
            m) COMMIT_MESSAGE="${OPTARG}" ;;
            b) DEFAULT_BRANCH="${OPTARG}" ;;
            i) INTERVAL="${OPTARG}" ;;
            h) usage ;;
            *) usage ;;
        esac
    done

    # Validate repository directory
    if [[ ! -d "${REPO_DIR}" ]]; then
        log_message "ERROR: Directory does not exist: ${REPO_DIR}"
        exit 1
    fi

    # Single sync or continuous mode
    if [[ "${INTERVAL}" -eq 0 ]]; then
        sync_repo "${REPO_DIR}" "${COMMIT_MESSAGE}"
    else
        while true; do
            sync_repo "${REPO_DIR}" "${COMMIT_MESSAGE}"
            log_message "Waiting ${INTERVAL} seconds before next sync..."
            sleep "${INTERVAL}"
        done
    fi
}

# Run main function
main "$@"
