#!/bin/bash

# Common library for admin scripts
# Version: 1.0.0

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging levels
readonly LOG_ERROR="ERROR"
readonly LOG_WARNING="WARNING"
readonly LOG_INFO="INFO"

# Function to print formatted messages
print_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "${level}" in
        "${LOG_ERROR}")
            echo -e "${timestamp} [${RED}${level}${NC}] ${message}"
            ;;
        "${LOG_WARNING}")
            echo -e "${timestamp} [${YELLOW}${level}${NC}] ${message}"
            ;;
        "${LOG_INFO}")
            echo -e "${timestamp} [${GREEN}${level}${NC}] ${message}"
            ;;
        *)
            echo -e "${timestamp} [${level}] ${message}"
            ;;
    esac
}

# Function to check if script is running with root privileges
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_message "${LOG_ERROR}" "This script must be run as root"
        exit 1
    fi
}

# Function to validate input (basic implementation)
validate_input() {
    local input="$1"
    local pattern="$2"
    
    if [[ ! $input =~ $pattern ]]; then
        print_message "${LOG_ERROR}" "Invalid input format"
        return 1
    fi
    return 0
}

# Export all functions
export -f print_message
export -f check_root
export -f validate_input
