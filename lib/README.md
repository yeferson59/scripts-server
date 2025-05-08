# Common Library

## Overview
Shared library of common functions and utilities used across the server management scripts.

## Features
- Logging functions
- Error handling
- Configuration management
- Security utilities
- System health checks
- Common constants

## Configuration
1. Source the library:
   ```bash
   source ./lib/common.sh
   ```

2. Set log level:
   ```bash
   set_log_level "DEBUG"
   ```

3. Configure error handling:
   ```bash
   enable_error_handling
   ```

## Usage
1. Basic logging:
   ```bash
   log_info "Operation started"
   log_error "Error occurred"
   ```

2. Error handling:
   ```bash
   trap_errors
   handle_error "Error message"
   ```

3. Health checks:
   ```bash
   check_system_health
   verify_dependencies
   ```
