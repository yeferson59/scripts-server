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
#   check_root           Check if running as root
#   trap_errors          Set error handling
#   validate_input       Validate command input
#
# Examples:
#   source ./lib/common.sh
#   log_info "Starting process"
#   check_root || exit 1
#
# Note:
#   Must be sourced, not executed directly

