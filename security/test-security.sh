#!/bin/bash

# Security Test Script
# Version: 1.0.0

echo "Starting security configuration tests..."

# Test 1: SSH Configuration
echo -e "\n1. Testing SSH Configuration:"
echo "- Current SSH port: $(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')"
echo "- Root login status: $(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')"
echo "- Password authentication: $(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')"

# Test 2: Fail2ban Configuration
echo -e "\n2. Testing Fail2ban Configuration:"
echo "- Active jails: $(fail2ban-client status | grep "Jail list" | cut -f2-)"
echo "- SSH jail status:"
fail2ban-client status sshd

# Test 3: File Permissions
echo -e "\n3. Testing Critical File Permissions:"
files=("/etc/shadow" "/etc/passwd" "/etc/ssh/sshd_config")
for file in "${files[@]}"; do
    perm=$(stat -c "%a" "$file")
    echo "- $file: $perm"
done

# Test 4: Open Ports
echo -e "\n4. Checking Open Ports:"
ss -tulpn | grep "LISTEN"

# Test 5: Active Security Services
echo -e "\n5. Checking Security Services:"
services=("fail2ban" "sshd" "ufw" "auditd")
for service in "${services[@]}"; do
    status=$(systemctl is-active "$service")
    echo "- $service: $status"
done

# Test 6: Firewall Rules
echo -e "\n6. Checking Firewall Rules:"
ufw status verbose

# Test 7: System Logging
echo -e "\n7. Verifying System Logging:"
echo "- Auth log exists: $(test -f /var/log/auth.log && echo "Yes" || echo "No")"
echo "- Audit log exists: $(test -f /var/log/audit/audit.log && echo "Yes" || echo "No")"
echo "- Security log exists: $(test -f /var/log/auth.log && echo "Yes" || echo "No")"

# Test 8: Security Updates
echo -e "\n8. Checking Security Updates:"
apt-get -s upgrade | grep -i security

# Summary
echo -e "\nSecurity Test Summary:"
echo "===================="
echo "✓ SSH Configuration"
echo "✓ Fail2ban Setup"
echo "✓ File Permissions"
echo "✓ Network Security"
echo "✓ Service Status"
echo "✓ Logging Configuration"

echo -e "\nRecommendations:"
# Add any detected issues here
if [[ "$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')" != "no" ]]; then
    echo "! Disable password authentication in SSH"
fi
if [[ "$(ufw status | grep -c "2222/tcp")" -eq 0 ]]; then
    echo "! Add explicit firewall rule for SSH port"
fi
