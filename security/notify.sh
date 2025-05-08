#!/bin/bash

# Multi-channel Security Notification Script
# Version: 1.0.0

# Configuration file
CONFIG_FILE="/etc/admin-scripts/notification.conf"

# Create configuration directory
sudo mkdir -p /etc/admin-scripts

# Function to configure email notifications
configure_email() {
    echo "Configuring Gmail notifications..."
    echo "Please go to https://myaccount.google.com/apppasswords to generate an app password"
    read -p "Gmail address: " gmail_address
    read -s -p "Gmail app password: " gmail_password
    echo
    
    # Update Postfix configuration
    sudo postconf -e "relayhost = [smtp.gmail.com]:587"
    sudo postconf -e "smtp_sasl_auth_enable = yes"
    sudo postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
    sudo postconf -e "smtp_sasl_security_options = noanonymous"
    sudo postconf -e "smtp_tls_security_level = encrypt"
    
    # Update SASL password file
    echo "[smtp.gmail.com]:587 ${gmail_address}:${gmail_password}" | sudo tee /etc/postfix/sasl_passwd > /dev/null
    sudo postmap /etc/postfix/sasl_passwd
    sudo chmod 600 /etc/postfix/sasl_passwd
    
    # Save configuration
    echo "EMAIL_ENABLED=true" | sudo tee -a ${CONFIG_FILE}
    echo "EMAIL_ADDRESS=${gmail_address}" | sudo tee -a ${CONFIG_FILE}
    
    # Restart Postfix
    sudo systemctl restart postfix
}

# Function to configure Telegram notifications
configure_telegram() {
    echo "Configuring Telegram notifications..."
    echo "Please create a Telegram bot using @BotFather and get the token"
    read -p "Bot Token: " telegram_token
    echo "Send a message to @getidsbot to get your chat ID"
    read -p "Chat ID: " telegram_chat_id
    
    # Save configuration
    echo "TELEGRAM_ENABLED=true" | sudo tee -a ${CONFIG_FILE}
    echo "TELEGRAM_TOKEN=${telegram_token}" | sudo tee -a ${CONFIG_FILE}
    echo "TELEGRAM_CHAT_ID=${telegram_chat_id}" | sudo tee -a ${CONFIG_FILE}
}

# Function to send notifications
send_notification() {
    local subject="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Load configuration
    source ${CONFIG_FILE}
    
    # Send email if enabled
    if [[ "${EMAIL_ENABLED}" == "true" ]]; then
        echo "${message}" | mail -s "[Security Alert] ${subject}" "${EMAIL_ADDRESS}"
    fi
    
    # Send Telegram message if enabled
    if [[ "${TELEGRAM_ENABLED}" == "true" ]]; then
        curl -s -X POST \
            "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=🚨 Security Alert: ${subject}%0A%0A${message}" \
            -d "parse_mode=HTML"
    fi
    
    # Log notification
    echo "${timestamp} - ${subject}" >> /var/log/admin-scripts/security/notifications.log
    echo "${message}" >> /var/log/admin-scripts/security/notifications.log
}

# Main menu
echo "Security Notification Setup"
echo "1. Configure Email Notifications"
echo "2. Configure Telegram Notifications"
echo "3. Test Notifications"
echo "4. Exit"

read -p "Select an option (1-4): " option

case ${option} in
    1) configure_email ;;
    2) configure_telegram ;;
    3) send_notification "Test Alert" "This is a test security notification." ;;
    4) exit 0 ;;
    *) echo "Invalid option" ;;
esac
