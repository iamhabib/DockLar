#!/bin/bash

function reload_host_nginx() {
    if ! sudo nginx -t; then
        display "danger" "Nginx configuration test failed"
        return 1
    fi

    if sudo systemctl reload nginx; then
        display "success" "Nginx reloaded with new configuration"
        return 0
    fi

    display "warning" "Nginx reload failed, trying restart..."
    if ! sudo systemctl restart nginx; then
        display "danger" "Failed to reload/restart Nginx"
        return 1
    fi

    display "success" "Nginx restarted with new configuration"
}

function ensure_connection_upgrade_map() {
    local map_path="/etc/nginx/conf.d/00-connection-upgrade.conf"
    if [ -f "$map_path" ]; then
        return 0
    fi

    if ! printf '%s\n' \
        'map $http_upgrade $connection_upgrade {' \
        '    default upgrade;' \
        "    ''      close;" \
        '}' | sudo tee "$map_path" > /dev/null; then
        display "error" "Failed to write Nginx WebSocket map config"
        return 1
    fi
}

function install_nginx_if_not_installed() {
    if command -v nginx >/dev/null 2>&1 || dpkg -s nginx >/dev/null 2>&1; then
        display "info" "Nginx is already installed."
        return 0
    fi

    display "info" "Nginx is not installed. Installing..."

    if ! sudo apt update; then
        display "error" "Failed to update package list"
        return 1
    fi

    if ! sudo apt install nginx -y; then
        display "error" "Failed to install Nginx"
        return 1
    fi

    display "success" "Nginx has been installed successfully."
}

function sed_escape() {
    # Escape characters that are special in sed replacement when using | as delimiter
    printf '%s' "$1" | sed -e 's/[\\|&]/\\&/g'
}

function write_host_nginx_config() {
    local template_path="$1"
    local destination_path="$2"
    local host_port host_url upload_size container_port

    host_port="$(sed_escape "${HOST_PORT}")"
    host_url="$(sed_escape "${HOST_URL}")"
    upload_size="$(sed_escape "${PHP_UPLOAD_MAX_FILESIZE}")"
    container_port="$(sed_escape "${CONTAINER_PORT}")"

    if ! sudo sed -e "s|{{HOST_PORT}}|${host_port}|g" \
        -e "s|{{HOST_URL}}|${host_url}|g" \
        -e "s|{{PHP_UPLOAD_MAX_FILESIZE}}|${upload_size}|g" \
        -e "s|{{CONTAINER_PORT}}|${container_port}|g" \
        "${template_path}" | sudo tee "${destination_path}" > /dev/null; then
        display "danger" "Failed to create Nginx config file"
        return 1
    fi
    display "success" "Nginx config file created at ${destination_path}"
}

function remove_host_machine_nginx() {
    if [ -z "${HOST_URL}" ] || [ -z "${HOST_PORT}" ] || [ -z "${CONTAINER_PORT}" ]; then
        display "error" "Required environment variables are not set"
        return 1
    fi

    local nginx_file_name="${HOST_URL}_${HOST_PORT}_${CONTAINER_PORT}.conf"
    local enabled_path="/etc/nginx/sites-enabled/${nginx_file_name}"
    local available_path="/etc/nginx/sites-available/${nginx_file_name}"

    if [ -f "${enabled_path}" ] || [ -L "${enabled_path}" ]; then
        if ! sudo rm -f "${enabled_path}"; then
            display "error" "Failed to remove ${enabled_path}"
            return 1
        fi
        display "info" "Removed ${enabled_path}"
    fi

    if [ -f "${available_path}" ]; then
        if ! sudo rm -f "${available_path}"; then
            display "error" "Failed to remove ${available_path}"
            return 1
        fi
        display "info" "Removed ${available_path}"
    fi

    reload_host_nginx
}

function set_up_host_machine_nginx() {
    if [ -z "${HOST_URL}" ] || [ -z "${HOST_PORT}" ] || [ -z "${CONTAINER_PORT}" ] || [ -z "${PHP_UPLOAD_MAX_FILESIZE}" ]; then
        display "error" "Required environment variables are not set"
        return 1
    fi

    if ! install_nginx_if_not_installed; then
        display "error" "Failed to install Nginx"
        return 1
    fi

    if ! ensure_connection_upgrade_map; then
        return 1
    fi

    local nginx_file_name="${HOST_URL}_${HOST_PORT}_${CONTAINER_PORT}.conf"
    local template_path="./bash/reverse_proxy.conf"
    local destination_path="/etc/nginx/sites-available/${nginx_file_name}"
    local enabled_path="/etc/nginx/sites-enabled/${nginx_file_name}"

    if [ ! -f "${template_path}" ]; then
        display "danger" "Template file ${template_path} not found!"
        return 1
    fi

    if [ -f "${destination_path}" ]; then
        display "warning" "Nginx config already exists at ${destination_path}."
        display "warning" "Overwriting it will remove Let's Encrypt SSL settings if they were added."
        display "info" "Overwrite this file?"
        if ! get_user_choice; then
            display "info" "Keeping existing Nginx config."
        elif ! write_host_nginx_config "${template_path}" "${destination_path}"; then
            return 1
        fi
    elif ! write_host_nginx_config "${template_path}" "${destination_path}"; then
        return 1
    fi

    if [ ! -f "${destination_path}" ]; then
        display "danger" "Failed to create Nginx config file!"
        return 1
    fi

    if [ ! -L "${enabled_path}" ]; then
        if ! sudo ln -sf "${destination_path}" "${enabled_path}"; then
            display "error" "Failed to create symlink"
            return 1
        fi
        display "success" "Symlink created for ${HOST_URL}"
    else
        display "info" "Symlink for ${nginx_file_name} already exists"
    fi

    reload_host_nginx
}
