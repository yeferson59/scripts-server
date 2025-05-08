#!/bin/bash

# Colores para mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con formato
print_message() {
    echo -e "${2}[${1}] ${3}${NC}"
}

# Función para verificar si el script se ejecuta como root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_message "ERROR" "$RED" "Este script debe ejecutarse como root o con sudo"
        exit 1
    fi
}

# Función para hacer backup de la lista de paquetes instalados
backup_packages() {
    BACKUP_DIR="/root/package_backups"
    BACKUP_FILE="$BACKUP_DIR/packages_$(date +%Y%m%d_%H%M%S).list"

    mkdir -p "$BACKUP_DIR"
    dpkg --get-selections > "$BACKUP_FILE"
    print_message "INFO" "$GREEN" "Backup de paquetes creado en $BACKUP_FILE"
}

# Función principal de actualización
update_system() {
    print_message "INFO" "$GREEN" "Iniciando actualización del sistema..."

    # Actualizar la lista de paquetes
    print_message "INFO" "$YELLOW" "Actualizando lista de paquetes..."
    apt update

    # Realizar backup antes de actualizar
    backup_packages

    # Actualizar todos los paquetes
    print_message "INFO" "$YELLOW" "Actualizando paquetes..."
    apt full-upgrade -y

    # Eliminar paquetes innecesarios
    print_message "INFO" "$YELLOW" "Eliminando paquetes innecesarios..."
    apt autoremove -y

    # Limpiar la caché de apt
    print_message "INFO" "$YELLOW" "Limpiando caché de apt..."
    apt clean

    # Eliminar archivos de configuración huérfanos
    print_message "INFO" "$YELLOW" "Eliminando configuraciones huérfanas..."
    apt purge -y $(dpkg -l | awk '/^rc/ {print $2}')

    # Verificar si hay paquetes rotos
    if ! apt-get check >/dev/null 2>&1; then
        print_message "WARNING" "$YELLOW" "Detectados paquetes rotos. Intentando reparar..."
        apt --fix-broken install -y
    fi

    # Mostrar paquetes actualizados
    print_message "INFO" "$GREEN" "Paquetes actualizados recientemente:"
    grep "upgrade" /var/log/dpkg.log | tail -n 10

    print_message "SUCCESS" "$GREEN" "Actualización del sistema completada"
}

# Función para manejar errores
handle_error() {
    print_message "ERROR" "$RED" "Se produjo un error durante la ejecución"
    exit 1
}

# Configurar trap para manejar errores
trap handle_error ERR

# Inicio del script
check_root
update_system

exit 0
