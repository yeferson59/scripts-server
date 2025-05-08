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

# Solicitar información
read -p "Nombre de usuario: " USERNAME
read -s -p "Contraseña: " PASSWORD
echo
read -p "¿Agregar al grupo sudo? (s/n): " SUDO_ACCESS

# Crear usuario
useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# Agregar a sudo si se solicita
if [ "$SUDO_ACCESS" = "s" ]; then
    usermod -aG sudo "$USERNAME"
    print_message "INFO" "$GREEN" "Usuario agregado al grupo sudo"
fi

print_message "SUCCESS" "$GREEN" "Usuario $USERNAME creado exitosamente"
