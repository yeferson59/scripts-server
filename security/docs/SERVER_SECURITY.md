# Server Security Configuration Guide

Comprehensive guide for securing a Linux server with best practices and implementation steps.

## Table of Contents

1. [Initial Server Setup](#initial-server-setup)
2. [User Management](#user-management)
3. [SSH Configuration](#ssh-configuration)
4. [Firewall Setup](#firewall-setup)
5. [System Updates](#system-updates)
6. [Security Monitoring](#security-monitoring)
7. [Logging and Auditing](#logging-and-auditing)
8. [Malware Protection](#malware-protection)
9. [Network Security](#network-security)
10. [Backups](#backups)

## Initial Server Setup

### SSH Access Hardening
```bash
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# Recommended settings:
Port 2222                    # Change default SSH port
PermitRootLogin no          # Disable root login
PasswordAuthentication no    # Disable password authentication
PubkeyAuthentication yes     # Enable key-based authentication
Protocol 2                   # Use SSH protocol 2
```

### Update System
```bash
sudo apt update
sudo apt upgrade
```

## User Management

### Create Admin User
```bash
# Create user with sudo privileges
sudo adduser admin
sudo usermod -aG sudo admin

# Set up SSH key authentication
mkdir -p /home/admin/.ssh
chmod 700 /home/admin/.ssh
touch /home/admin/.ssh/authorized_keys
chmod 600 /home/admin/.ssh/authorized_keys
```

## Firewall Setup

### UFW Configuration
```bash
# Install UFW
sudo apt install ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (use custom port if configured)
sudo ufw allow 2222/tcp  # Replace with your SSH port

# Enable firewall
sudo ufw enable
```

## System Hardening

### Secure Shared Memory
```bash
# Add to /etc/fstab
tmpfs     /run/shm     tmpfs     defaults,noexec,nosuid     0     0
```

### Disable USB Storage
```bash
# Add to /etc/modprobe.d/blacklist.conf
blacklist usb_storage
```

### Secure sysctl Settings
```bash
# Add to /etc/sysctl.conf
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
```

## Security Monitoring

### Install and Configure Fail2ban
```bash
sudo apt install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Configure jail.local
[sshd]
enabled = true
bantime = 3600
findtime = 600
maxretry = 3
```

### Security Auditing
```bash
# Install auditd
sudo apt install auditd

# Configure audit rules
sudo nano /etc/audit/rules.d/audit.rules
```

## Logging and Auditing

### Configure System Logging
```bash
# Install rsyslog
sudo apt install rsyslog

# Configure remote logging if needed
sudo nano /etc/rsyslog.conf
```

## Malware Protection

### Install and Configure ClamAV
```bash
sudo apt install clamav clamav-daemon
sudo freshclam
```

### Install RootKit Hunter
```bash
sudo apt install rkhunter
sudo rkhunter --update
sudo rkhunter --propupd
```

## Network Security

### Install and Configure Fail2ban
```bash
sudo apt install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

### Configure TCP Wrappers
```bash
sudo nano /etc/hosts.allow
sudo nano /etc/hosts.deny
```

## Backups

### Configure Automated Backups
```bash
# Install backup utilities
sudo apt install rsync

# Set up cron job for backups
sudo crontab -e
```

## Regular Maintenance

### Daily Tasks
- Check system logs
- Monitor user activities
- Review failed login attempts
- Check system resources

### Weekly Tasks
- Update system packages
- Review audit logs
- Check backup integrity
- Scan for malware

### Monthly Tasks
- Full system audit
- Review user accounts
- Update security policies
- Test recovery procedures

## Security Best Practices

1. Principle of Least Privilege
2. Regular Updates and Patches
3. Strong Password Policies
4. Network Segmentation
5. Regular Security Audits
6. Incident Response Plan
7. Employee Training
8. Documentation

## Emergency Procedures

### In Case of Security Breach
1. Isolate affected systems
2. Document all actions
3. Analyze breach source
4. Report to authorities if required
5. Implement corrective measures

### Recovery Procedures
1. Restore from clean backups
2. Reset all credentials
3. Review and update security measures
4. Document lessons learned

## Monitoring Tools

- Fail2ban
- RKHunter
- ClamAV
- Auditd
- OSSEC
- Nagios

## Regular Updates

This guide should be reviewed and updated regularly to maintain security standards.

Last updated: $(date +%Y-%m-%d)
