#!/bin/bash

function install_nginx_if_not_installed() {
    if dpkg -l | grep -q "^ii.*nginx\s" 2>/dev/null; then
        display "info" "Nginx is already installed."
    else
        display "info" "Nginx is not installed. Installing..."

        if ! sudo apt update; then
            display "error" "Failed to update package list"
            return 1
        fi

        if ! sudo apt install nginx -y; then
            display "error" "Failed to install Nginx"
            return 1
        fi

        if ! sudo chown -R $USER /etc/nginx/sites-available; then
            display "error" "Failed to set permissions for Nginx sites-available"
            return 1
        fi

        display "success" "Nginx has been installed successfully."
    fi
}

function remove_host_machine_nginx() {
    # Validate required environment variables
    if [ -z "${HOST_URL}" ] || [ -z "${HOST_PORT}" ] || [ -z "${CONTAINER_PORT}" ]; then
        display "error" "Required environment variables are not set"
        return 1
    fi

    local nginx_file_name="${HOST_URL}_${HOST_PORT}_${CONTAINER_PORT}.conf"
    local enabled_path="/etc/nginx/sites-enabled/${nginx_file_name}"
    local available_path="/etc/nginx/sites-available/${nginx_file_name}"

    # Remove from sites-enabled
    if [ -f "${enabled_path}" ] || [ -L "${enabled_path}" ]; then
        if ! sudo rm -f "${enabled_path}"; then
            display "error" "Failed to remove ${enabled_path}"
            return 1
        fi
        display "info" "Removed ${enabled_path}"
    fi

    # Remove from sites-available
    if [ -f "${available_path}" ]; then
        if ! sudo rm -f "${available_path}"; then
            display "error" "Failed to remove ${available_path}"
            return 1
        fi
        display "info" "Removed ${available_path}"
    fi

    # Test and reload Nginx configuration
    if ! sudo nginx -t; then
        display "danger" "Nginx configuration test failed"
        return 1
    fi

    if ! sudo systemctl reload nginx || ! sudo systemctl restart nginx; then
        display "danger" "Failed to reload/restart Nginx"
        return 1
    fi

    display "success" "Nginx reloaded with new configuration"
}

function set_up_host_machine_nginx() {
    # Validate required environment variables
    if [ -z "${HOST_URL}" ] || [ -z "${HOST_PORT}" ] || [ -z "${CONTAINER_PORT}" ] || [ -z "${PHP_UPLOAD_MAX_FILESIZE}" ]; then
        display "error" "Required environment variables are not set"
        return 1
    fi

    # Install Nginx if not present
    if ! install_nginx_if_not_installed; then
        display "error" "Failed to install Nginx"
        return 1
    fi

    local nginx_file_name="${HOST_URL}_${HOST_PORT}_${CONTAINER_PORT}.conf"
    local template_path="./bash/reverse_proxy.conf"
    local destination_path="/etc/nginx/sites-available/${nginx_file_name}"
    local enabled_path="/etc/nginx/sites-enabled/${nginx_file_name}"

    # Verify template exists
    if [ ! -f "${template_path}" ]; then
        display "danger" "Template file ${template_path} not found!"
        return 1
    fi

    # Create Nginx configuration
    if ! sudo sed -e "s/{{HOST_PORT}}/${HOST_PORT}/g" \
        -e "s/{{HOST_URL}}/${HOST_URL}/g" \
        -e "s/{{PHP_UPLOAD_MAX_FILESIZE}}/${PHP_UPLOAD_MAX_FILESIZE}/g" \
        -e "s/{{CONTAINER_PORT}}/${CONTAINER_PORT}/g" \
        "${template_path}" | sudo tee "${destination_path}" > /dev/null; then
        display "danger" "Failed to create Nginx config file"
        return 1
    fi

    # Verify config file creation
    if [ ! -f "${destination_path}" ]; then
        display "danger" "Failed to create Nginx config file!"
        return 1
    fi
    display "success" "Nginx config file created at ${destination_path}"

    # Create symlink if it doesn't exist
    if [ ! -L "${enabled_path}" ]; then
        if ! sudo ln -sf "${destination_path}" "${enabled_path}"; then
            display "error" "Failed to create symlink"
            return 1
        fi
        display "success" "Symlink created for ${HOST_URL}"
    else
        display "info" "Symlink for ${nginx_file_name} already exists"
    fi

    # Test and reload Nginx configuration
    if ! sudo nginx -t; then
        display "danger" "Nginx configuration test failed"
        return 1
    fi

    if ! sudo systemctl reload nginx || ! sudo systemctl restart nginx; then
        display "danger" "Failed to reload/restart Nginx"
        return 1
    fi

    display "success" "Nginx reloaded with new configuration"
}
