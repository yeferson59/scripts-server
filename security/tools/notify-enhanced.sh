#!/bin/bash

# Enhanced Security Notification Script
# Version: 1.0.0

# Configuration file
CONFIG_FILE="/etc/admin-scripts/notification.conf"
LOG_FILE="/var/log/admin-scripts/security/notifications.log"

# Ensure log directory exists
sudo mkdir -p "$(dirname "${LOG_FILE}")"
sudo chown -R $USER:$USER "$(dirname "${LOG_FILE}")"

# Function to configure email with app password
configure_email() {
    echo "Configuring Gmail notifications..."
    echo "Please follow these steps:"
    echo "1. Go to https://myaccount.google.com/security"
    echo "2. Enable 2-Step Verification if not already enabled"
    echo "3. Go to https://myaccount.google.com/apppasswords"
    echo "4. Generate an app password for 'Mail' and 'Linux Server'"
    echo
    read -p "Gmail address: " gmail_address
    read -s -p "App password (16 characters): " gmail_password
    echo

    if [[ ${#gmail_password} != 16 ]]; then
        echo "Error: App password must be 16 characters long"
        return 1
    fi

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
    echo "EMAIL_ENABLED=true" | sudo tee ${CONFIG_FILE}
    echo "EMAIL_ADDRESS=${gmail_address}" | sudo tee -a ${CONFIG_FILE}

    # Restart Postfix
    sudo systemctl restart postfix

    # Test email
    echo "Sending test email..."
    echo "This is a test email from your server" | mail -s "Test Security Alert" "${gmail_address}"
}

# Function to configure Slack notifications
configure_slack() {
    echo "Configuring Slack notifications..."
    echo "Please follow these steps:"
    echo "1. Go to https://api.slack.com/apps"
    echo "2. Create New App -> From scratch"
    echo "3. Add 'Incoming Webhooks' feature"
    echo "4. Create New Webhook -> Copy Webhook URL"
    echo
    read -p "Slack Webhook URL: " slack_webhook
    read -p "Channel (e.g., #security-alerts): " slack_channel

    # Save configuration
    echo "SLACK_ENABLED=true" | sudo tee -a ${CONFIG_FILE}
    echo "SLACK_WEBHOOK=${slack_webhook}" | sudo tee -a ${CONFIG_FILE}
    echo "SLACK_CHANNEL=${slack_channel}" | sudo tee -a ${CONFIG_FILE}

    # Test Slack notification
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"🔒 Test security alert from server\"}" \
        "${slack_webhook}"
}

# Function to send notifications
send_notification() {
    local subject="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Load configuration
    source ${CONFIG_FILE}

    # Log the notification
    echo "${timestamp} - ${subject}" >> "${LOG_FILE}"
    echo "${message}" >> "${LOG_FILE}"

    # Send email if enabled
    if [[ "${EMAIL_ENABLED}" == "true" ]]; then
        echo "${message}" | mail -s "[Security Alert] ${subject}" "${EMAIL_ADDRESS}"
    fi

    # Send Slack message if enabled
    if [[ "${SLACK_ENABLED}" == "true" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 *${subject}*\n${message}\"}" \
            "${SLACK_WEBHOOK}"
    fi
}

# Main menu
main_menu() {
    while true; do
        echo
        echo "Security Notification Setup"
        echo "----------------------------"
        echo "1. Configure Email Notifications (Gmail)"
        echo "2. Configure Slack Notifications"
        echo "3. Test Notification System"
        echo "4. View Notification Logs"
        echo "5. Exit"
        echo
        read -p "Select an option (1-5): " option

        case ${option} in
            1) configure_email ;;
            2) configure_slack ;;
            3) send_notification "Test Alert" "This is a test security notification." ;;
            4) tail -n 20 "${LOG_FILE}" ;;
            5) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

# Run main menu
main_menu
