#!/bin/bash

# Notification Configuration Script
CONFIG_DIR="/etc/admin-scripts"
CONFIG_FILE="${CONFIG_DIR}/notification.conf"

# Ensure config directory exists
sudo mkdir -p "${CONFIG_DIR}"

# Function to configure email
configure_email() {
    echo "Configuring email notifications..."
    echo "Please go to https://myaccount.google.com/apppasswords to generate an app password"
    read -p "Gmail address: " email
    read -s -p "App password (16 characters): " password
    echo
    
    if [[ ${#password} != 16 ]]; then
        echo "Error: App password must be 16 characters"
        return 1
    fi
    
    # Save email configuration
    sudo tee "${CONFIG_FILE}" > /dev/null << EOL
EMAIL_ENABLED=true
EMAIL_ADDRESS="${email}"
EOL

    # Configure Postfix
    sudo postconf -e "relayhost = [smtp.gmail.com]:587"
    sudo postconf -e "smtp_sasl_auth_enable = yes"
    sudo postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
    sudo postconf -e "smtp_sasl_security_options = noanonymous"
    sudo postconf -e "smtp_tls_security_level = encrypt"

    # Update password file
    echo "[smtp.gmail.com]:587 ${email}:${password}" | sudo tee /etc/postfix/sasl_passwd > /dev/null
    sudo postmap /etc/postfix/sasl_passwd
    sudo chmod 600 /etc/postfix/sasl_passwd

    # Restart Postfix
    sudo systemctl restart postfix

    # Send test email
    echo "Sending test email..."
    echo "This is a test email from your server's security monitoring system" | mail -s "Security Monitor Test" "${email}"
    
    echo "Email configuration completed. Please check your inbox for the test email."
}

# Function to test notifications
test_notification() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
        if [[ "${EMAIL_ENABLED}" == "true" ]]; then
            echo "Sending test notification..."
            echo "Test security alert at $(date)" | mail -s "Security Alert Test" "${EMAIL_ADDRESS}"
            echo "Test notification sent to ${EMAIL_ADDRESS}"
        else
            echo "Email notifications not configured"
        fi
    else
        echo "No notification configuration found"
    fi
}

# Main menu
echo "Notification Configuration"
echo "------------------------"
echo "1. Configure Email Notifications"
echo "2. Test Current Configuration"
echo "3. Exit"
read -p "Select an option (1-3): " option

case ${option} in
    1) configure_email ;;
    2) test_notification ;;
    3) exit 0 ;;
    *) echo "Invalid option" ;;
esac
