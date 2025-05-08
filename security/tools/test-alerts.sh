#!/bin/bash

# Security Alert Test Script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/notify-enhanced.sh"

echo "Running security alert tests..."

# Test 1: System Load Alert
echo "1. Testing system load alert..."
yes > /dev/null & 
pid1=$!
yes > /dev/null & 
pid2=$!
sleep 5
kill $pid1 $pid2

# Test 2: Disk Space Alert
echo "2. Testing disk space alert..."
dd if=/dev/zero of=/tmp/test_file bs=1M count=1024 2>/dev/null
sleep 2
rm /tmp/test_file

# Test 3: Failed Login Attempts
echo "3. Testing failed login detection..."
echo "$(date) Failed password for invalid user test from 127.0.0.1" | sudo tee -a /var/log/auth.log

# Test 4: File Modification Alert
echo "4. Testing file modification detection..."
sudo touch /etc/test-security-file
sleep 2
sudo rm /etc/test-security-file

# Test 5: Network Connection Alert
echo "5. Testing network connection detection..."
nc -l 12345 > /dev/null 2>&1 & 
sleep 1
nc localhost 12345 < /dev/null 2>&1
killall nc 2>/dev/null

echo -e "\nChecking alert logs..."
echo "Recent alerts:"
tail -n 10 /var/log/admin-scripts/security/monitor.log

echo -e "\nChecking notification delivery..."
if [[ -f "/etc/admin-scripts/notification.conf" ]]; then
    source "/etc/admin-scripts/notification.conf"
    if [[ "${EMAIL_ENABLED}" == "true" ]]; then
        echo "Email notifications enabled. Check ${EMAIL_ADDRESS} for test alerts."
    fi
    if [[ "${SLACK_ENABLED}" == "true" ]]; then
        echo "Slack notifications enabled. Check ${SLACK_CHANNEL} for test alerts."
    fi
fi
