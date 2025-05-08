#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Función para mensajes
print_message() {
    echo -e "${2}[${1}] ${3}${NC}"
}

# Verificar root
if [ "$EUID" -ne 0 ]; then
    print_message "ERROR" "$RED" "Este script debe ejecutarse como root"
    exit 1
fi

# Limpiar logs antiguos
print_message "INFO" "$GREEN" "Limpiando logs antiguos..."
find /var/log -type f -name "*.log.*" -mtime +30 -delete
find /var/log -type f -name "*.gz" -mtime +30 -delete

# Limpiar directorio temporal
print_message "INFO" "$GREEN" "Limpiando directorio temporal..."
rm -rf /tmp/*
rm -rf /var/tmp/*

# Limpiar caché de apt
print_message "INFO" "$GREEN" "Limpiando caché de apt..."
apt-get clean
apt-get autoremove -y

# Limpiar journalctl
print_message "INFO" "$GREEN" "Limpiando journalctl..."
journalctl --vacuum-time=30d

print_message "SUCCESS" "$GREEN" "Limpieza completada"
