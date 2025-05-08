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

# Información del sistema
print_message "INFO" "$GREEN" "=== Información del Sistema ==="
echo "Uptime: $(uptime)"
echo "Uso de CPU:"
top -bn1 | head -n 3
echo "Uso de Memoria:"
free -h
echo "Uso de Disco:"
df -h
echo "Procesos más pesados:"
ps aux --sort=-%mem | head -n 5
echo "Conexiones activas:"
netstat -an | grep ESTABLISHED | wc -l

# Verificar servicios críticos
services=("nginx" "mysql" "ssh" "apache2")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        print_message "INFO" "$GREEN" "$service está ejecutándose"
    else
        print_message "WARNING" "$YELLOW" "$service no está ejecutándose"
    fi
done
