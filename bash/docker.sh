#!/bin/bash

function install_docker() {
    set -e  # Exit on any error
    set -x  # Enable debug mode

    # Update package list
    if ! sudo apt update; then
        display "error" "Failed to update package list"
        exit 1
    fi

    # Install Docker
    if ! sudo apt install docker.io -y; then
        display "error" "Failed to install Docker"
        exit 1
    fi

    # Start and enable Docker service
    if ! sudo systemctl start docker || ! sudo systemctl enable docker; then
        display "error" "Failed to start or enable Docker service"
        exit 1
    fi

    # Add the current user to the docker group
    if ! sudo usermod -aG docker $USER; then
        display "error" "Failed to add user to Docker group"
        exit 1
    fi

    newgrp docker;

    # Test Docker installation
    if ! docker --version; then
        display "error" "Docker installation failed"
        exit 1
    fi

    set +x  # Disable debug mode

    display "success" "Docker Installation Done"
}

function install_docker_compose() {
    set -e  # Exit on any error
    set -x  # Enable debug mode

    # Install Docker Compose
    if ! sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; then
        display "error" "Failed to download Docker Compose"
        exit 1
    fi

    if ! sudo chmod +x /usr/local/bin/docker-compose; then
        display "error" "Failed to set executable permissions for Docker Compose"
        exit 1
    fi

    # Test Docker Compose installation
    if ! docker-compose --version; then
        display "error" "Docker Compose installation failed"
        exit 1
    fi

    set +x  # Disable debug mode

    display "success" "Docker Compose Installation Done"
}

function docker_compose_up() {
    # Check if the port is already in use
    if (echo >/dev/tcp/localhost/${CONTAINER_PORT}) >/dev/null 2>&1; then
        echo "❌ Port ${CONTAINER_PORT} is already in use. Please choose a different port or stop the service using this port."
        exit 1
    else
        echo "✅ Port ${CONTAINER_PORT} is available."
    fi
    
    # Build and start the containers
    local compose_file="-f docker-compose.yml"
    if [ "${ENABLE_CRON}" = "true" ]; then
        compose_file="${compose_file} -f docker-compose.cron.yml"
    fi
    if [ "${ENABLE_JOB}" = "true" ]; then
        compose_file="${compose_file} -f docker-compose.job.yml"
    fi

    display "info" "Executing: docker-compose ${compose_file} up"

    docker-compose ${compose_file} build --no-cache
    docker-compose ${compose_file} up -d
}

function docker_compose_down() {

    # Stop all containers
    local compose_file="-f docker-compose.yml"
    if [ "${ENABLE_CRON}" = "true" ]; then
        compose_file="${compose_file} -f docker-compose.cron.yml"
    fi
    if [ "${ENABLE_JOB}" = "true" ]; then
        compose_file="${compose_file} -f docker-compose.job.yml"
    fi

    display "info" "Executing: docker-compose ${compose_file} down"

    docker-compose ${compose_file} down --rmi all --volumes
}
