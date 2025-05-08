#!/bin/bash

# backup-docker.sh

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuración
BACKUP_DIR="/backup/docker"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Función para mensajes
print_message() {
    echo -e "${2}[${1}] ${3}${NC}"
}

# Verificar root
if [ "$EUID" -ne 0 ]; then
    print_message "ERROR" "$RED" "Este script debe ejecutarse como root"
    exit 1
fi

# Crear directorio de backup
mkdir -p "$BACKUP_DIR"

# Backup de docker-compose files
print_message "INFO" "$GREEN" "Respaldando archivos docker-compose..."
if [ -d "/opt/docker" ]; then
    tar -czf "$BACKUP_DIR/docker_compose_$DATE.tar.gz" /opt/docker
fi

# Backup de volúmenes Docker
print_message "INFO" "$GREEN" "Respaldando volúmenes Docker..."
VOLUMES=$(docker volume ls -q)
if [ ! -z "$VOLUMES" ]; then
    mkdir -p "$BACKUP_DIR/volumes_$DATE"
    for volume in $VOLUMES; do
        print_message "INFO" "$YELLOW" "Respaldando volumen: $volume"
        docker run --rm -v "$volume":/source:ro -v "$BACKUP_DIR/volumes_$DATE":/backup alpine tar -czf "/backup/$volume.tar.gz" -C /source .
    done
    tar -czf "$BACKUP_DIR/docker_volumes_$DATE.tar.gz" "$BACKUP_DIR/volumes_$DATE"
    rm -rf "$BACKUP_DIR/volumes_$DATE"
fi

# Backup de contenedores MySQL/MariaDB
print_message "INFO" "$GREEN" "Buscando contenedores MySQL/MariaDB..."
MYSQL_CONTAINERS=$(docker ps -q --filter "ancestor=mysql" --filter "ancestor=mariadb")
for container in $MYSQL_CONTAINERS; do
    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
    print_message "INFO" "$YELLOW" "Respaldando base de datos del contenedor: $CONTAINER_NAME"
    docker exec "$container" mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases > "$BACKUP_DIR/mysql_${CONTAINER_NAME}_$DATE.sql"
done

# Backup de contenedores PostgreSQL
print_message "INFO" "$GREEN" "Buscando contenedores PostgreSQL..."
POSTGRES_CONTAINERS=$(docker ps -q --filter "ancestor=postgres")
for container in $POSTGRES_CONTAINERS; do
    CONTAINER_NAME=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
    print_message "INFO" "$YELLOW" "Respaldando base de datos del contenedor: $CONTAINER_NAME"
    docker exec "$container" pg_dumpall -U postgres > "$BACKUP_DIR/postgres_${CONTAINER_NAME}_$DATE.sql"
done

# Guardar información de las imágenes Docker
print_message "INFO" "$GREEN" "Guardando lista de imágenes Docker..."
docker images > "$BACKUP_DIR/docker_images_$DATE.txt"

# Guardar información de los contenedores
print_message "INFO" "$GREEN" "Guardando configuración de contenedores..."
docker ps -a > "$BACKUP_DIR/docker_containers_$DATE.txt"

# Guardar información de las redes Docker
print_message "INFO" "$GREEN" "Guardando configuración de redes Docker..."
docker network ls > "$BACKUP_DIR/docker_networks_$DATE.txt"

# Comprimir todos los backups del día
tar -czf "$BACKUP_DIR/docker_full_backup_$DATE.tar.gz" "$BACKUP_DIR"/*_"$DATE"*
rm "$BACKUP_DIR"/*_"$DATE"* 2>/dev/null

# Eliminar backups antiguos
find "$BACKUP_DIR" -name "docker_full_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

print_message "SUCCESS" "$GREEN" "Backup de Docker completado"

# Mostrar espacio utilizado por los backups
du -sh "$BACKUP_DIR"
