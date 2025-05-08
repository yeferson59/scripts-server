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

# Verificar intentos de login fallidos
print_message "INFO" "$GREEN" "Verificando intentos de login fallidos..."
grep "Failed password" /var/log/auth.log | tail -n 5

# Verificar puertos abiertos
print_message "INFO" "$GREEN" "Puertos abiertos:"
netstat -tuln

# Verificar usuarios con acceso SSH
print_message "INFO" "$GREEN" "Usuarios con acceso SSH:"
grep "Accepted" /var/log/auth.log | tail -n 5

# Verificar últimos accesos al sistema
print_message "INFO" "$GREEN" "Últimos accesos al sistema:"
last | head -n 5

# Verificar procesos sospechosos
print_message "INFO" "$GREEN" "Procesos con alto consumo de recursos:"
ps aux | awk '{if($3>50.0) print $0}'

# Verificar cambios en archivos importantes
print_message "INFO" "$GREEN" "Archivos importantes modificados recientemente:"
find /etc -type f -mtime -1 -ls
