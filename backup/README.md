# 💾 Backup Management System

## Overview
Automated backup system for server data, configurations, and Docker containers.

## Features
- Automated backup scheduling
- Data verification
- Compression support
- Remote backup capability
- Docker container/volume backup
- Retention management

## Scripts
- `backup-docker.sh`: Docker container and volume backup
  - Exports container states
  - Backs up volumes
  - Verifies backup integrity
  - Manages retention

## Configuration
Located in `../config/`:
```bash
# Backup settings
BACKUP_RETENTION_DAYS=30
BACKUP_COMPRESSION=true
REMOTE_BACKUP_ENABLED=false
```

## Usage
```bash
# Run Docker backup
sudo ./backup-docker.sh

# Verify backups
sudo ./backup-docker.sh --verify

# List backups
sudo ./backup-docker.sh --list
```

## Backup Locations
- Local: `/var/backups/docker/`
- Remote: Configured in config files

## Scheduling
Automated via cron:
```bash
# Daily Docker backup at 1 AM
0 1 * * * /path/to/backup-docker.sh
```

## Recovery Procedures
1. List available backups
2. Select backup to restore
3. Verify backup integrity
4. Restore data

## Monitoring
- Backup success/failure logged
- Email notifications
- Integration with monitoring system

## Last Updated: $(date '+%Y-%m-%d %H:%M:%S')
