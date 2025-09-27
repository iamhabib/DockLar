#!/bin/bash

# Source nginx configuration and utilities
source ./bash/nginx.sh
source ./bash/utility.sh  # Add this to access display function and env variables

# Ensure nginx is installed before proceeding
install_nginx_if_not_installed

function install_certbot() {
    if ! command -v certbot &> /dev/null; then  # Better command existence check
        display "info" "Certbot is not installed. Installing..."

        # Error handling for each step
        if ! (sudo snap install core && sudo snap refresh core); then
            display "error" "Failed to install/refresh snap core"
            return 1
        fi

        if ! sudo snap install --classic certbot; then
            display "error" "Failed to install certbot"
            return 1
        fi

        if ! sudo ln -sf /snap/bin/certbot /usr/bin/certbot; then  # Use -sf to force symlink
            display "error" "Failed to create certbot symlink"
            return 1
        fi

        display "success" "Certbot has been installed successfully."
    else
        display "info" "Certbot is already installed."
    fi
}

function install_ssl_certificate() {
    # Ensure HOST_URL is set
    if [ -z "${HOST_URL}" ]; then
        display "error" "HOST_URL is not set in environment"
        return 1
    fi

    # Install certbot if not present
    if ! install_certbot; then
        display "error" "Failed to install certbot"
        return 1
    fi

    # Attempt to install SSL certificate
    if ! sudo certbot --nginx -d "${HOST_URL}"; then
        display "error" "Failed to install SSL certificate for ${HOST_URL}"
        return 1
    fi

    display "success" "SSL certificate installed successfully for ${HOST_URL}"
}
