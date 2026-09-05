#!/bin/bash

# Run docker as the login user. If this session is not yet in the docker
# group, fall back to sudo docker (passwordless on typical EC2 ubuntu).
function run_docker() {
    if docker info >/dev/null 2>&1; then
        docker "$@"
    else
        sudo docker "$@"
    fi
}

function run_compose() {
    if docker info >/dev/null 2>&1; then
        if docker compose version >/dev/null 2>&1; then
            docker compose "$@"
            return
        fi
        if command -v docker-compose >/dev/null 2>&1; then
            docker-compose "$@"
            return
        fi
    fi

    if sudo docker info >/dev/null 2>&1; then
        if sudo docker compose version >/dev/null 2>&1; then
            sudo docker compose "$@"
            return
        fi
        if command -v docker-compose >/dev/null 2>&1; then
            sudo docker-compose "$@"
            return
        fi
    fi

    display "error" "Docker Compose is not installed or Docker is not running"
    return 1
}

function compose_files() {
    echo -n "-f docker-compose.yml"
    if [ "${ENABLE_CRON}" = "true" ]; then
        echo -n " -f docker-compose.cron.yml"
    fi
    if [ "${ENABLE_JOB}" = "true" ]; then
        echo -n " -f docker-compose.job.yml"
    fi
}

function install_docker_and_compose() {
    local target_user
    target_user="$(get_login_user)"

    if ! sudo apt update; then
        display "error" "Failed to update package list"
        return 1
    fi

    if ! sudo apt install -y docker.io docker-compose; then
        display "error" "Failed to install Docker"
        return 1
    fi

    if ! sudo systemctl enable docker; then
        display "error" "Failed to enable Docker service"
        return 1
    fi

    if ! sudo systemctl start docker; then
        display "error" "Failed to start Docker service"
        return 1
    fi

    if ! sudo usermod -aG docker "$target_user"; then
        display "error" "Failed to add user ${target_user} to Docker group"
        return 1
    fi

    if ! sudo docker --version; then
        display "error" "Docker installation failed"
        return 1
    fi

    display "success" "Docker Installation Done"
    display "info" "User '${target_user}' was added to the docker group. This session still uses sudo docker until you log out and back in. After re-login, docker runs as ${target_user} without sudo."
}

function docker_compose_up() {
    if (echo >/dev/tcp/localhost/${CONTAINER_PORT}) >/dev/null 2>&1; then
        echo "❌ Port ${CONTAINER_PORT} is already in use. Please choose a different port or stop the service using this port."
        exit 1
    else
        echo "✅ Port ${CONTAINER_PORT} is available."
    fi

    local files
    files="$(compose_files)"

    display "info" "Executing: docker compose ${files} up"

    # shellcheck disable=SC2086
    run_compose ${files} build --no-cache
    # shellcheck disable=SC2086
    run_compose ${files} up -d --remove-orphans
}

function docker_compose_down() {
    local files
    files="$(compose_files)"

    display "info" "Executing: docker compose ${files} down"

    # Stop this project's containers. Do not delete images or volumes
    # (unsafe on production). --remove-orphans cleans cron/job if flags were turned off.
    # shellcheck disable=SC2086
    run_compose ${files} down --remove-orphans
}

function prune_unused_docker_images() {
    run_docker image prune -a -f
    display "success" "Unused Docker images were deleted"
}
