# Firewall Configuration Documentation

## Current Configuration

### Default Policies
- Incoming: DENY (default deny all incoming traffic)
- Outgoing: ALLOW (default allow all outgoing traffic)

### Allowed Services
- SSH (Port 2222/tcp) - Rate limited
    - Custom port for security through obscurity
    - Rate limiting prevents brute force attacks

### Blocked Services
1. Common Attack Vectors:
    - Port 23 (Telnet)
    - Port 445 (Microsoft-DS)
    - Port 1433 (SQL Server)
    - Port 3389 (RDP)

### Blocked Networks
Known malicious networks blocked:
- 218.92.0.0/24
- 176.65.142.0/24
- 185.164.32.0/24

## Security Measures

1. Rate Limiting
    - SSH connections are rate-limited to prevent brute force attacks
    - Helps maintain server availability while preventing abuse

2. Network Blocks
    - Entire subnets known for malicious activity are blocked
    - Prevents attacks from known bad actors

## Maintenance

### Adding New Rules
```bash
# Allow new service
sudo ufw allow <port>/<protocol>

# Block new network
sudo ufw deny from <ip_range> to any
```

### Checking Status
```bash
# Show numbered rules
sudo ufw status numbered

# Show verbose status
sudo ufw status verbose
```

### Backup and Restore
Backup files location: /etc/ufw/
- user.rules
- before.rules
- after.rules
- user6.rules
- before6.rules
- after6.rules

## Emergency Procedures

### Temporary Lockdown
```bash
# Block all incoming traffic
sudo ufw default deny incoming
sudo ufw default deny outgoing
sudo ufw allow 2222/tcp
```

### Reset to Safe Defaults
```bash
# Reset and reconfigure
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2222/tcp
sudo ufw enable
```

Last updated: $(date '+%Y-%m-%d %H:%M:%S')
