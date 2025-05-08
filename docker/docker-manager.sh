#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Función para mostrar el menú principal
show_main_menu() {
    clear
    echo "=== Docker Manager ==="
    echo "1. Gestión de Contenedores"
    echo "2. Gestión de Swarm"
    echo "3. Gestión de Secretos"
    echo "4. Mantenimiento"
    echo "5. Salir"
}

# Función para mostrar el menú de contenedores
show_containers_menu() {
    clear
    echo "=== Gestión de Contenedores ==="
    echo "1. Ver estado de contenedores"
    echo "2. Reiniciar todos los contenedores"
    echo "3. Actualizar imágenes"
    echo "4. Ver logs de contenedor"
    echo "5. Ver uso de recursos"
    echo "6. Reiniciar contenedor específico"
    echo "7. Ingresar a un contenedor"
    echo "8. Volver al menú principal"
}

# Función para mostrar el menú de Swarm
show_swarm_menu() {
    clear
    echo "=== Gestión de Swarm ==="
    echo "1. Ver estado del Swarm"
    echo "2. Listar nodos"
    echo "3. Listar servicios"
    echo "4. Listar stacks"
    echo "5. Desplegar stack"
    echo "6. Eliminar stack"
    echo "7. Actualizar servicio"
    echo "8. Ver logs de servicio"
    echo "9. Escalar servicio"
    echo "10. Drenar/Activar nodo"
    echo "11. Unir nodo al Swarm"
    echo "12. Volver al menú principal"
}

# Función para mostrar el menú de secretos
show_secrets_menu() {
    clear
    echo "=== Gestión de Secretos ==="
    echo "1. Listar secretos"
    echo "2. Crear nuevo secreto"
    echo "3. Eliminar secreto"
    echo "4. Actualizar secreto"
    echo "5. Ver detalles de secreto"
    echo "6. Volver al menú principal"
}

# Función para mostrar el menú de mantenimiento
show_maintenance_menu() {
    clear
    echo "=== Mantenimiento ==="
    echo "1. Limpiar recursos no utilizados"
    echo "2. Limpiar logs de Docker"
    echo "3. Verificar salud del sistema"
    echo "4. Backup de configuraciones"
    echo "5. Volver al menú principal"
}

# Funciones de Swarm
show_swarm_status() {
    print_message "INFO" "$GREEN" "Estado del Swarm:"
    docker node ls
    echo ""
    print_message "INFO" "$GREEN" "Servicios activos:"
    docker service ls
}

list_nodes() {
    print_message "INFO" "$GREEN" "Nodos del Swarm:"
    docker node ls --format "table {{.ID}}\t{{.Hostname}}\t{{.Status}}\t{{.Availability}}\t{{.ManagerStatus}}"
}

list_services() {
    print_message "INFO" "$GREEN" "Servicios del Swarm:"
    docker service ls --format "table {{.ID}}\t{{.Name}}\t{{.Replicas}}\t{{.Image}}\t{{.Ports}}"
}

deploy_stack() {
    read -p "Ruta del archivo docker-compose.yml: " compose_file
    read -p "Nombre del stack: " stack_name
    if [ -f "$compose_file" ]; then
        docker stack deploy -c "$compose_file" "$stack_name"
        print_message "SUCCESS" "$GREEN" "Stack desplegado"
    else
        print_message "ERROR" "$RED" "Archivo no encontrado"
    fi
}

remove_stack() {
    docker stack ls
    read -p "Nombre del stack a eliminar: " stack_name
    docker stack rm "$stack_name"
    print_message "SUCCESS" "$GREEN" "Stack eliminado"
}

update_service() {
    docker service ls
    read -p "Nombre del servicio: " service_name
    read -p "Nueva imagen (ejemplo: nginx:latest): " new_image
    docker service update --image "$new_image" "$service_name"
    print_message "SUCCESS" "$GREEN" "Servicio actualizado"
}

service_logs() {
    clear
    print_message "INFO" "$GREEN" "Servicios disponibles:"

    # Crear arrays con los IDs y nombres de los servicios
    mapfile -t SERVICE_IDS < <(docker service ls --format "{{.ID}}")
    mapfile -t SERVICE_NAMES < <(docker service ls --format "{{.Name}}")

    # Verificar si hay servicios
    if [ ${#SERVICE_IDS[@]} -eq 0 ]; then
        print_message "ERROR" "$RED" "No hay servicios en ejecución"
        return;
    fi

    # Mostrar lista numerada de servicios
    echo "ID    NOMBRE    IMAGEN    REPLICAS    PUERTOS"
    echo "------------------------------------------------"
    for i in "${!SERVICE_IDS[@]}"; do
        SERVICE_INFO=$(docker service ls --format "{{.ID}}\t{{.Name}}\t{{.Image}}\t{{.Replicas}}\t{{.Ports}}" | grep "${SERVICE_IDS[$i]}")
        echo "[$i] $SERVICE_INFO"
    done

    echo ""
    read -p "Seleccione el número del servicio: " selection

    # Validar selección
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -lt "${#SERVICE_IDS[@]}" ]; then
        SELECTED_ID="${SERVICE_IDS[$selection]}"
        SELECTED_NAME="${SERVICE_NAMES[$selection]}"

        print_message "INFO" "$YELLOW" "Mostrando logs del servicio $SELECTED_NAME..."
        echo "Para salir presione Ctrl+C"
        echo "-----------------------------------"

        # Opciones adicionales para los logs
        echo "Opciones de visualización:"
        echo "1. Ver últimos logs (live)"
        echo "2. Ver últimas N líneas"
        echo "3. Ver logs desde una fecha específica"
        echo "4. Ver logs de una tarea específica del servicio"
        read -p "Seleccione una opción: " log_option

        case $log_option in
            1)
                docker service logs -f "$SELECTED_ID"
                ;;
            2)
                read -p "¿Cuántas líneas desea ver? " num_lines
                docker service logs --tail "$num_lines" -f "$SELECTED_ID"
                ;;
            3)
                read -p "Ingrese la fecha (formato: YYYY-MM-DD HH:MM:SS): " since_date
                docker service logs --since "$since_date" -f "$SELECTED_ID"
                ;;
            4)
                echo "Tareas disponibles para el servicio $SELECTED_NAME:"
                docker service ps "$SELECTED_ID" --format "table {{.ID}}\t{{.Name}}\t{{.Node}}\t{{.CurrentState}}"
                read -p "Ingrese el ID de la tarea: " task_id
                docker service logs "$SELECTED_ID.$task_id"
                ;;
            *)
                print_message "ERROR" "$RED" "Opción inválida"
                ;;
        esac
    else
        print_message "ERROR" "$RED" "Selección inválida"
    fi
}

scale_service() {
    docker service ls
    read -p "Nombre del servicio: " service_name
    read -p "Número de réplicas: " replicas
    docker service scale "$service_name"="$replicas"
    print_message "SUCCESS" "$GREEN" "Servicio escalado"
}

manage_node() {
    docker node ls
    read -p "ID del nodo: " node_id
    read -p "Acción (drain/active): " action
    if [ "$action" = "drain" ]; then
        docker node update --availability drain "$node_id"
    elif [ "$action" = "active" ]; then
        docker node update --availability active "$node_id"
    fi
    print_message "SUCCESS" "$GREEN" "Estado del nodo actualizado"
}

# Funciones de Secretos
list_secrets() {
    print_message "INFO" "$GREEN" "Secretos existentes:"
    docker secret ls
}

create_secret() {
    read -p "Nombre del secreto: " secret_name
    read -p "Valor del secreto: " secret_value
    echo "$secret_value" | docker secret create "$secret_name" -
    print_message "SUCCESS" "$GREEN" "Secreto creado"
}

delete_secret() {
    docker secret ls
    read -p "Nombre del secreto a eliminar: " secret_name
    docker secret rm "$secret_name"
    print_message "SUCCESS" "$GREEN" "Secreto eliminado"
}

update_secret() {
    docker secret ls
    read -p "Nombre del secreto actual: " old_secret
    read -p "Nuevo nombre del secreto: " new_secret
    read -p "Nuevo valor del secreto: " secret_value
    docker secret rm "$old_secret"
    echo "$secret_value" | docker secret create "$new_secret" -
    print_message "SUCCESS" "$GREEN" "Secreto actualizado"
}

view_secret_details() {
    docker secret ls
    read -p "Nombre del secreto: " secret_name
    docker secret inspect "$secret_name"
}

list_stacks() {
    print_message "INFO" "$GREEN" "Stacks desplegados:"
    docker stack ls
    echo ""
    read -p "¿Desea ver los servicios de algún stack específico? (s/n): " show_services
    if [ "$show_services" = "s" ]; then
        read -p "Nombre del stack: " stack_name
        print_message "INFO" "$GREEN" "Servicios del stack $stack_name:"
        docker stack services "$stack_name"
    fi
}

join_swarm() {
    echo "=== Unir nodo al Swarm ==="
    echo "1. Como Manager"
    echo "2. Como Worker"
    read -p "Seleccione el tipo de nodo: " node_type

    if [ "$node_type" = "1" ]; then
        print_message "INFO" "$YELLOW" "Generando token de Manager..."
        docker swarm join-token manager
    elif [ "$node_type" = "2" ]; then
        print_message "INFO" "$YELLOW" "Generando token de Worker..."
        docker swarm join-token worker
    else
        print_message "ERROR" "$RED" "Opción inválida"
    fi
}

# Funciones que faltaban para contenedores
show_status() {
    print_message "INFO" "$GREEN" "Estado de contenedores:"
    docker ps -a
    echo ""
    print_message "INFO" "$GREEN" "Uso de recursos:"
    docker stats --no-stream
}

restart_containers() {
    print_message "INFO" "$YELLOW" "Reiniciando todos los contenedores..."
    docker-compose -f /opt/docker/docker-compose.yml down
    docker-compose -f /opt/docker/docker-compose.yml up -d
    print_message "SUCCESS" "$GREEN" "Contenedores reiniciados"
}

update_images() {
    print_message "INFO" "$YELLOW" "Actualizando imágenes..."
    docker-compose -f /opt/docker/docker-compose.yml pull
    print_message "INFO" "$YELLOW" "Reiniciando contenedores con nuevas imágenes..."
    docker-compose -f /opt/docker/docker-compose.yml up -d
    print_message "SUCCESS" "$GREEN" "Actualización completada"
}

view_logs() {
    clear
    print_message "INFO" "$GREEN" "Contenedores disponibles:"

    # Crear arrays con los IDs y nombres de los contenedores
    mapfile -t CONTAINER_IDS < <(docker ps --format "{{.ID}}")
    mapfile -t CONTAINER_NAMES < <(docker ps --format "{{.Names}}")

    # Mostrar lista numerada de contenedores
    echo "ID    NOMBRE    IMAGEN    ESTADO"
    echo "----------------------------------------"
    for i in "${!CONTAINER_IDS[@]}"; do
        CONTAINER_INFO=$(docker ps --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}" | grep "${CONTAINER_IDS[$i]}")
        echo "[$i] $CONTAINER_INFO"
    done

    echo ""
    read -p "Seleccione el número del contenedor: " selection

    # Validar selección
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -lt "${#CONTAINER_IDS[@]}" ]; then
        SELECTED_ID="${CONTAINER_IDS[$selection]}"

        print_message "INFO" "$YELLOW" "Mostrando logs del contenedor ${CONTAINER_NAMES[$selection]}..."
        echo "Para salir presione Ctrl+C"
        echo "-----------------------------------"

        # Opciones adicionales para los logs
        echo "Opciones de visualización:"
        echo "1. Ver últimos logs (live)"
        echo "2. Ver últimas N líneas"
        echo "3. Ver logs desde una fecha específica"
        read -p "Seleccione una opción: " log_option

        case $log_option in
            1)
                docker logs -f "$SELECTED_ID"
                ;;
            2)
                read -p "¿Cuántas líneas desea ver? " num_lines
                docker logs --tail "$num_lines" -f "$SELECTED_ID"
                ;;
            3)
                read -p "Ingrese la fecha (formato: YYYY-MM-DD HH:MM:SS): " since_date
                docker logs --since "$since_date" -f "$SELECTED_ID"
                ;;
            *)
                print_message "ERROR" "$RED" "Opción inválida"
                ;;
        esac
    else
        print_message "ERROR" "$RED" "Selección inválida"
    fi
}

show_resources() {
    docker stats --no-stream
}

enter_container() {
    clear
    print_message "INFO" "$GREEN" "Contenedores disponibles:"

    # Crear un array con los IDs de los contenedores
    mapfile -t CONTAINER_IDS < <(docker ps --format "{{.ID}}")
    mapfile -t CONTAINER_NAMES < <(docker ps --format "{{.Names}}")

    # Mostrar lista numerada de contenedores
    echo "ID    NOMBRE    IMAGEN    ESTADO"
    echo "----------------------------------------"
    for i in "${!CONTAINER_IDS[@]}"; do
        CONTAINER_INFO=$(docker ps --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}" | grep "${CONTAINER_IDS[$i]}")
        echo "[$i] $CONTAINER_INFO"
    done

    echo ""
    read -p "Seleccione el número del contenedor: " selection

    # Validar selección
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -lt "${#CONTAINER_IDS[@]}" ]; then
        SELECTED_ID="${CONTAINER_IDS[$selection]}"

        print_message "INFO" "$YELLOW" "Ingresando al contenedor ${CONTAINER_NAMES[$selection]}..."
        echo "Para salir del contenedor use: exit"
        echo "-----------------------------------"

        # Intentar detectar y usar el shell disponible
        if docker exec "$SELECTED_ID" which bash >/dev/null 2>&1; then
            docker exec -it "$SELECTED_ID" bash
        elif docker exec "$SELECTED_ID" which sh >/dev/null 2>&1; then
            docker exec -it "$SELECTED_ID" sh
        else
            print_message "ERROR" "$RED" "No se encontró un shell disponible en el contenedor"
        fi
    else
        print_message "ERROR" "$RED" "Selección inválida"
    fi
}

restart_specific() {
    docker ps
    read -p "Ingrese el nombre del contenedor a reiniciar: " container_name
    docker restart "$container_name"
    print_message "SUCCESS" "$GREEN" "Contenedor $container_name reiniciado"
}

# Funciones de mantenimiento que faltaban
system_health_check() {
    print_message "INFO" "$GREEN" "Verificando salud del sistema Docker..."
    echo "=== Estado del Daemon ==="
    systemctl status docker --no-pager

    echo -e "\n=== Información del Sistema ==="
    docker system df

    echo -e "\n=== Estado de Swarm ==="
    docker node ls 2>/dev/null || echo "Swarm no está activo"

    echo -e "\n=== Contenedores con problemas ==="
    docker ps -a --filter "status=exited" --filter "status=created" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
}

backup_configs() {
    BACKUP_DIR="/opt/docker/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    # Backup de docker-compose files
    print_message "INFO" "$YELLOW" "Respaldando archivos de configuración..."
    if [ -d "/opt/docker" ]; then
        cp -r /opt/docker/*.{yml,yaml} "$BACKUP_DIR/" 2>/dev/null || true
    fi

    # Backup de secrets
    print_message "INFO" "$YELLOW" "Respaldando lista de secretos..."
    docker secret ls > "$BACKUP_DIR/secrets.txt"

    # Backup de configuración de Swarm
    print_message "INFO" "$YELLOW" "Respaldando configuración de Swarm..."
    docker node ls > "$BACKUP_DIR/swarm_nodes.txt"
    docker stack ls > "$BACKUP_DIR/swarm_stacks.txt"

    print_message "SUCCESS" "$GREEN" "Backup completado en $BACKUP_DIR"
}

clean_resources() {
    print_message "INFO" "$YELLOW" "Limpiando recursos no utilizados..."

    read -p "¿Desea eliminar todos los contenedores detenidos? (s/n): " remove_containers
    if [ "$remove_containers" = "s" ]; then
        docker container prune -f
    fi

    read -p "¿Desea eliminar todas las imágenes sin usar? (s/n): " remove_images
    if [ "$remove_images" = "s" ]; then
        docker image prune -a -f
    fi

    read -p "¿Desea eliminar todos los volúmenes sin usar? (s/n): " remove_volumes
    if [ "$remove_volumes" = "s" ]; then
        docker volume prune -f
    fi

    read -p "¿Desea eliminar todas las redes sin usar? (s/n): " remove_networks
    if [ "$remove_networks" = "s" ]; then
        docker network prune -f
    fi

    docker system prune -f
    print_message "SUCCESS" "$GREEN" "Limpieza completada"
}

clean_logs() {
    print_message "INFO" "$YELLOW" "Limpiando logs de Docker..."
    truncate -s 0 /var/lib/docker/containers/*/*-json.log
    print_message "SUCCESS" "$GREEN" "Logs limpiados"
}

# Función principal para manejar el menú de Swarm
handle_swarm_menu() {
    while true; do
        show_swarm_menu
        read -p "Seleccione una opción: " option
        case $option in
            1) show_swarm_status ;;
            2) list_nodes ;;
            3) list_services ;;
            4) list_stacks ;;
            5) deploy_stack ;;
            6) remove_stack ;;
            7) update_service ;;
            8) service_logs ;;
            9) scale_service ;;
            10) manage_node ;;
            11) join_swarm ;;
            12) return ;;
            *) print_message "ERROR" "$RED" "Opción inválida" ;;
        esac
        read -p "Presione Enter para continuar..."
    done
}

# Función principal para manejar el menú de secretos
handle_secrets_menu() {
    while true; do
        show_secrets_menu
        read -p "Seleccione una opción: " option
        case $option in
            1) list_secrets ;;
            2) create_secret ;;
            3) delete_secret ;;
            4) update_secret ;;
            5) view_secret_details ;;
            6) return ;;
            *) print_message "ERROR" "$RED" "Opción inválida" ;;
        esac
        read -p "Presione Enter para continuar..."
    done
}

# Función principal para manejar el menú de contenedores
handle_containers_menu() {
    while true; do
        show_containers_menu
        read -p "Seleccione una opción: " option
        case $option in
            1) show_status ;;
            2) restart_containers ;;
            3) update_images ;;
            4) view_logs ;;
            5) show_resources ;;
            6) restart_specific ;;
            7) enter_container ;;
            8) return ;;
            *) print_message "ERROR" "$RED" "Opción inválida" ;;
        esac
        read -p "Presione Enter para continuar..."
    done
}

# Función principal para manejar el menú de mantenimiento
handle_maintenance_menu() {
    while true; do
        show_maintenance_menu
        read -p "Seleccione una opción: " option
        case $option in
            1) clean_resources ;;
            2) clean_logs ;;
            3) system_health_check ;;
            4) backup_configs ;;
            5) return ;;
            *) print_message "ERROR" "$RED" "Opción inválida" ;;
        esac
        read -p "Presione Enter para continuar..."
    done
}

# Loop principal
while true; do
    show_main_menu
    read -p "Seleccione una opción: " main_option
    case $main_option in
        1) handle_containers_menu ;;
        2) handle_swarm_menu ;;
        3) handle_secrets_menu ;;
        4) handle_maintenance_menu ;;
        5)
            print_message "INFO" "$GREEN" "Saliendo..."
            exit 0
            ;;
        *) print_message "ERROR" "$RED" "Opción inválida" ;;
    esac
done
