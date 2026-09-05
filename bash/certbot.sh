#!/bin/bash

function install_certbot() {
    if ! command -v certbot &> /dev/null; then
        display "info" "Certbot is not installed. Installing..."

        if ! (sudo snap install core && sudo snap refresh core); then
            display "error" "Failed to install/refresh snap core"
            return 1
        fi

        if ! sudo snap install --classic certbot; then
            display "error" "Failed to install certbot"
            return 1
        fi

        if ! sudo ln -sf /snap/bin/certbot /usr/bin/certbot; then
            display "error" "Failed to create certbot symlink"
            return 1
        fi

        display "success" "Certbot has been installed successfully."
    else
        display "info" "Certbot is already installed."
    fi
}

function install_ssl_certificate() {
    if [ -z "${HOST_URL}" ] || [ -z "${HOST_PORT}" ] || [ -z "${CONTAINER_PORT}" ]; then
        display "error" "HOST_URL, HOST_PORT, and CONTAINER_PORT must be set in .env"
        return 1
    fi

    if [ "${HOST_PORT}" != "80" ]; then
        display "error" "Let's Encrypt HTTP-01 requires HOST_PORT=80 (currently HOST_PORT=${HOST_PORT}). Set HOST_PORT=80, recreate the Nginx server block, then retry."
        return 1
    fi

    if ! install_nginx_if_not_installed; then
        display "error" "Failed to install Nginx"
        return 1
    fi

    local nginx_file_name="${HOST_URL}_${HOST_PORT}_${CONTAINER_PORT}.conf"
    local available_path="/etc/nginx/sites-available/${nginx_file_name}"
    local enabled_path="/etc/nginx/sites-enabled/${nginx_file_name}"

    if [ ! -f "${available_path}" ] && [ ! -L "${enabled_path}" ]; then
        display "error" "Nginx server block for ${HOST_URL} not found. Create it first (option: Create NGINX Server Block)."
        return 1
    fi

    if ! install_certbot; then
        display "error" "Failed to install certbot"
        return 1
    fi

    if ! sudo certbot --nginx -d "${HOST_URL}"; then
        display "error" "Failed to install SSL certificate for ${HOST_URL}"
        return 1
    fi

    display "success" "SSL certificate installed successfully for ${HOST_URL}"
}
