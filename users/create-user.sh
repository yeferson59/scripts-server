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

show_help() {
    cat <<'EOF'
Gestión de usuarios

Uso:
  ./users/create-user.sh --create <usuario>
  ./users/create-user.sh --list-users
  ./users/create-user.sh --view-perms <usuario>
  ./users/create-user.sh --modify-perms <usuario>
  ./users/create-user.sh --manage-ssh <usuario>
  ./users/create-user.sh [sin opciones]

Opciones:
  -h, --help               Muestra esta ayuda
  --create <usuario>       Crea un usuario nuevo
  --list-users             Lista usuarios locales
  --view-perms <usuario>   Muestra permisos/grupos del usuario
  --modify-perms <usuario> [--show|--grant-admin|--revoke-admin|--add-group <grupo>|--remove-group <grupo>]
                           Gestiona permisos del usuario
  --manage-ssh <usuario>   Inicializa ~/.ssh y authorized_keys del usuario
EOF
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        print_message "ERROR" "$RED" "Este script debe ejecutarse como root"
        exit 1
    fi
}

detect_admin_group() {
    if getent group sudo >/dev/null 2>&1; then
        echo "sudo"
        return 0
    fi

    if getent group wheel >/dev/null 2>&1; then
        echo "wheel"
        return 0
    fi

    return 1
}

ask_password() {
    local password
    while true; do
        read -s -p "Contraseña: " password
        echo
        if [[ -n "${password}" ]]; then
            echo "${password}"
            return 0
        fi
        print_message "ERROR" "$RED" "La contraseña no puede estar vacía"
    done
}

add_admin_access() {
    local username="$1"
    local admin_group
    admin_group="$(detect_admin_group)" || {
        print_message "WARNING" "$YELLOW" "No existe grupo administrativo (sudo/wheel). Se omite asignación."
        return 0
    }

    if usermod -aG "${admin_group}" "${username}"; then
        print_message "INFO" "$GREEN" "Usuario agregado al grupo ${admin_group}"
    else
        print_message "ERROR" "$RED" "No fue posible agregar ${username} al grupo ${admin_group}"
        return 1
    fi
}

remove_admin_access() {
    local username="$1"
    local admin_group
    admin_group="$(detect_admin_group)" || {
        print_message "WARNING" "$YELLOW" "No existe grupo administrativo (sudo/wheel)."
        return 0
    }

    remove_user_from_group "${username}" "${admin_group}"
}

show_user_permissions() {
    local username="$1"
    local groups
    local admin_group

    if ! id "${username}" >/dev/null 2>&1; then
        print_message "ERROR" "$RED" "El usuario ${username} no existe"
        return 1
    fi

    groups="$(id -nG "${username}" 2>/dev/null)"
    echo "Usuario: ${username}"
    echo "UID/GID: $(id -u "${username}")/$(id -g "${username}")"
    echo "Grupos: ${groups}"

    admin_group="$(detect_admin_group || true)"
    if [[ -n "${admin_group}" ]]; then
        if echo "${groups}" | tr ' ' '\n' | grep -qx "${admin_group}"; then
            print_message "INFO" "$GREEN" "Tiene permisos administrativos (${admin_group})"
        else
            print_message "INFO" "$YELLOW" "No tiene permisos administrativos (${admin_group})"
        fi
    fi
}

add_user_to_group() {
    local username="$1"
    local group_name="$2"

    if [[ -z "${group_name}" ]]; then
        print_message "ERROR" "$RED" "Debe indicar un grupo"
        return 1
    fi

    if ! getent group "${group_name}" >/dev/null 2>&1; then
        print_message "ERROR" "$RED" "El grupo ${group_name} no existe"
        return 1
    fi

    if id -nG "${username}" | tr ' ' '\n' | grep -qx "${group_name}"; then
        print_message "INFO" "$YELLOW" "El usuario ${username} ya pertenece al grupo ${group_name}"
        return 0
    fi

    if usermod -aG "${group_name}" "${username}"; then
        print_message "SUCCESS" "$GREEN" "Grupo ${group_name} agregado a ${username}"
    else
        print_message "ERROR" "$RED" "No fue posible agregar el grupo ${group_name}"
        return 1
    fi
}

remove_user_from_group() {
    local username="$1"
    local group_name="$2"
    local current_groups

    if [[ -z "${group_name}" ]]; then
        print_message "ERROR" "$RED" "Debe indicar un grupo"
        return 1
    fi

    if ! getent group "${group_name}" >/dev/null 2>&1; then
        print_message "ERROR" "$RED" "El grupo ${group_name} no existe"
        return 1
    fi

    if ! id -nG "${username}" | tr ' ' '\n' | grep -qx "${group_name}"; then
        print_message "INFO" "$YELLOW" "El usuario ${username} no pertenece al grupo ${group_name}"
        return 0
    fi

    if command -v gpasswd >/dev/null 2>&1; then
        if gpasswd -d "${username}" "${group_name}" >/dev/null; then
            print_message "SUCCESS" "$GREEN" "Grupo ${group_name} removido de ${username}"
            return 0
        fi
    fi

    current_groups="$(id -nG "${username}" | tr ' ' '\n' | grep -vx "${group_name}" | paste -sd, -)"
    if usermod -G "${current_groups}" "${username}"; then
        print_message "SUCCESS" "$GREEN" "Grupo ${group_name} removido de ${username}"
    else
        print_message "ERROR" "$RED" "No fue posible remover el grupo ${group_name}"
        return 1
    fi
}

list_users() {
    printf "%-20s %-8s %-18s %s\n" "USUARIO" "UID" "SHELL" "GRUPOS"
    while IFS=: read -r username _ uid _ _ _ shell; do
        if [[ "${uid}" -ge 1000 || "${username}" == "root" ]]; then
            printf "%-20s %-8s %-18s %s\n" \
                "${username}" \
                "${uid}" \
                "${shell}" \
                "$(id -nG "${username}" 2>/dev/null | tr ' ' ',')"
        fi
    done < /etc/passwd
}

create_user() {
    local username="$1"
    local password="$2"
    local admin_access="$3"

    if [[ -z "${username}" ]]; then
        print_message "ERROR" "$RED" "Debe indicar un nombre de usuario"
        return 1
    fi

    if id "${username}" >/dev/null 2>&1; then
        print_message "ERROR" "$RED" "El usuario ${username} ya existe"
        return 1
    fi

    useradd -m -s /bin/bash "${username}"
    echo "${username}:${password}" | chpasswd

    if [[ "${admin_access}" == "s" || "${admin_access}" == "S" ]]; then
        add_admin_access "${username}"
    fi

    print_message "SUCCESS" "$GREEN" "Usuario ${username} creado exitosamente"
}

modify_permissions() {
    local username="$1"
    local action="${2:-}"
    local group_name="${3:-}"
    local option

    if ! id "${username}" >/dev/null 2>&1; then
        print_message "ERROR" "$RED" "El usuario ${username} no existe"
        return 1
    fi

    case "${action}" in
        show)
            show_user_permissions "${username}"
            ;;
        grant-admin)
            add_admin_access "${username}"
            ;;
        revoke-admin)
            remove_admin_access "${username}"
            ;;
        add-group)
            add_user_to_group "${username}" "${group_name}"
            ;;
        remove-group)
            remove_user_from_group "${username}" "${group_name}"
            ;;
        "")
            echo "Gestión de permisos para ${username}:"
            echo "1) Ver permisos actuales"
            echo "2) Otorgar permisos administrativos"
            echo "3) Revocar permisos administrativos"
            echo "4) Agregar a grupo específico"
            echo "5) Quitar de grupo específico"
            read -p "Seleccione una opción (1-5): " option

            case "${option}" in
                1) show_user_permissions "${username}" ;;
                2) add_admin_access "${username}" ;;
                3) remove_admin_access "${username}" ;;
                4)
                    read -p "Grupo a agregar: " group_name
                    add_user_to_group "${username}" "${group_name}"
                    ;;
                5)
                    read -p "Grupo a quitar: " group_name
                    remove_user_from_group "${username}" "${group_name}"
                    ;;
                *)
                    print_message "ERROR" "$RED" "Opción no válida"
                    return 1
                    ;;
            esac
            ;;
        *)
            print_message "ERROR" "$RED" "Acción de permisos no válida: ${action}"
            return 1
            ;;
    esac
}

manage_ssh() {
    local username="$1"
    local user_home
    local ssh_dir
    local auth_keys

    if ! id "${username}" >/dev/null 2>&1; then
        print_message "ERROR" "$RED" "El usuario ${username} no existe"
        return 1
    fi

    user_home="$(getent passwd "${username}" | cut -d: -f6)"
    ssh_dir="${user_home}/.ssh"
    auth_keys="${ssh_dir}/authorized_keys"

    mkdir -p "${ssh_dir}"
    touch "${auth_keys}"
    chmod 700 "${ssh_dir}"
    chmod 600 "${auth_keys}"
    chown -R "${username}:${username}" "${ssh_dir}"

    print_message "SUCCESS" "$GREEN" "Configuración SSH preparada para ${username}"
}

interactive_create() {
    local username
    local password
    local admin_access

    read -p "Nombre de usuario: " username
    password="$(ask_password)"
    read -p "¿Agregar al grupo administrador (sudo/wheel)? (s/n): " admin_access
    create_user "${username}" "${password}" "${admin_access}"
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            return 0
            ;;
        --list-users)
            list_users
            return 0
            ;;
        --view-perms)
            [[ -n "${2:-}" ]] || { print_message "ERROR" "$RED" "Debe indicar el usuario"; return 1; }
            show_user_permissions "${2}"
            return 0
            ;;
        *)
            require_root
            ;;
    esac

    case "${1:-}" in
        --create)
            local username password admin_access
            username="${2:-}"
            if [[ -z "${username}" ]]; then
                read -p "Nombre de usuario: " username
            fi
            password="$(ask_password)"
            read -p "¿Agregar al grupo administrador (sudo/wheel)? (s/n): " admin_access
            create_user "${username}" "${password}" "${admin_access}"
            ;;
        --modify-perms)
            [[ -n "${2:-}" ]] || { print_message "ERROR" "$RED" "Debe indicar el usuario"; return 1; }
            case "${3:-}" in
                "") modify_permissions "${2}" ;;
                --show) modify_permissions "${2}" "show" ;;
                --grant-admin) modify_permissions "${2}" "grant-admin" ;;
                --revoke-admin) modify_permissions "${2}" "revoke-admin" ;;
                --add-group)
                    [[ -n "${4:-}" ]] || { print_message "ERROR" "$RED" "Debe indicar el grupo"; return 1; }
                    modify_permissions "${2}" "add-group" "${4}"
                    ;;
                --remove-group)
                    [[ -n "${4:-}" ]] || { print_message "ERROR" "$RED" "Debe indicar el grupo"; return 1; }
                    modify_permissions "${2}" "remove-group" "${4}"
                    ;;
                *)
                    print_message "ERROR" "$RED" "Opción no válida para --modify-perms: ${3}"
                    return 1
                    ;;
            esac
            ;;
        --manage-ssh)
            [[ -n "${2:-}" ]] || { print_message "ERROR" "$RED" "Debe indicar el usuario"; return 1; }
            manage_ssh "${2}"
            ;;
        "")
            interactive_create
            ;;
        *)
            print_message "ERROR" "$RED" "Opción no válida: ${1}"
            show_help
            return 1
            ;;
    esac
}

main "$@"
