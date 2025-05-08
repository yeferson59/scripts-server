# System Administration Scripts Collection

A comprehensive collection of shell scripts for system administration, monitoring, backup, and security tasks.

## Overview

This collection provides a suite of automated scripts for common system administration tasks:
- System monitoring and alerting
- Docker container and volume backup
- System cleanup and maintenance
- Security auditing and checks
- Centralized logging and reporting

## Requirements

- Bash shell (4.0 or later)
- Root access for installation and execution
- Required packages (installed automatically):
  - logrotate
  - rsync
  - bc
  - curl
  - mailutils/mailx

## Installation

1. Clone this repository:
   ```bash
   git clone <repository-url> /opt/admin-scripts
   cd /opt/admin-scripts
   ```

2. Run the installation script:
   ```bash
   sudo ./install.sh
   ```

The installer will:
- Create necessary directories
- Install required packages
- Configure logging
- Set up cron jobs
- Set appropriate permissions

## Configuration

### Environment Configuration

Scripts use environment-specific configuration files located in `config/`:
- `config-base.sh`: Common configuration settings
- `config-dev.sh`: Development environment settings
- `config-prod.sh`: Production environment settings

Set the environment using the `ENV` variable:
```bash
export ENV=prod  # or dev
```

### Alert Configuration

Configure alert endpoints in the appropriate config file:
```bash
readonly ALERT_EMAIL="admin@example.com"
readonly ALERT_SLACK_WEBHOOK="https://hooks.slack.com/services/..."
```

## Scripts

### monitor-system.sh
Monitors system resources and Docker containers:
- CPU, memory, and disk usage
- Docker container status
- Custom threshold alerts
- Runs every 5 minutes via cron

### backup-docker.sh
Performs Docker container and volume backups:
- Container state export
- Volume data backup
- Compression and verification
- Remote backup support
- Runs daily at 1 AM

### cleanup-system.sh
Performs system maintenance and cleanup:
- Log rotation and cleanup
- Temporary file removal
- Docker resource cleanup
- Package cache cleanup
- Runs daily at 3 AM

### security-check.sh
Performs security auditing and checks:
- Rootkit detection
- File integrity monitoring
- Process monitoring
- Permission checks
- Security log analysis
- Runs daily at 4 AM

## Logging

All scripts log to `/var/log/admin-scripts/`:
- `system-monitor.log`
- `docker-backup.log`
- `system-cleanup.log`
- `security-check.log`

Logs are automatically rotated using logrotate.

## Error Handling

All scripts include:
- Comprehensive error checking
- Detailed error logging
- Non-zero exit codes on failure
- Alert notifications for critical errors

## Security Features

- Root privilege checking
- Secure file permissions
- Input validation
- File integrity verification
- Audit logging

## Customization

1. Modify threshold values in config files
2. Adjust cron schedules in install.sh
3. Add custom alert endpoints in config files
4. Extend monitoring checks in monitor-system.sh
5. Add additional backup targets in backup-docker.sh

## Troubleshooting

1. Check logs in `/var/log/admin-scripts/`
2. Verify script permissions
3. Ensure root access when required
4. Check system requirements
5. Validate configuration settings

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

[Choose an appropriate license]

## Author

[Your Name/Organization]
