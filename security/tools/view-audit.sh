#!/bin/bash

REPORT_DIR="/var/log/admin-scripts/security/reports"

# List available reports
echo "Available audit reports:"
ls -1t "${REPORT_DIR}" | nl

# Prompt for report selection
read -p "Enter report number to view (or 'latest' for most recent): " choice

if [[ "${choice}" == "latest" ]]; then
    report=$(ls -t "${REPORT_DIR}" | head -n1)
else
    report=$(ls -1t "${REPORT_DIR}" | sed -n "${choice}p")
fi

if [[ -f "${REPORT_DIR}/${report}" ]]; then
    less "${REPORT_DIR}/${report}"
else
    echo "Invalid report selection"
fi
