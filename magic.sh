#!/bin/bash
set -euo pipefail

source ./bash/utility.sh
source ./bash/docker.sh
source ./bash/nginx.sh
source ./bash/certbot.sh

read_env_file
show_project_context

automation_options=(
    "Install Docker & Docker Compose"
    "Docker Compose Up"
    "Docker Compose Rebuild (no-cache)"
    "Docker Compose Down"
    "Docker PS"
    "Goto Bash"
    "Delete All Unused Docker Images"
    "Set Swap Memory"
    "Create NGINX Server Block"
    "Delete NGINX Server Block"
    "Install Lets Encrypt SSL Certificate"
    "Quit"
)

show_heading "Select Your Automation Option"
selected_automation=$(get_selection "${automation_options[@]}")

# Echo selection so logs/screenshots show what ran
if [ -n "$selected_automation" ] && [ "$selected_automation" != "Quit" ]; then
    show_heading "$selected_automation"
fi

case "$selected_automation" in
    "Install Docker & Docker Compose")
        install_docker_and_compose
        ;;
    "Docker Compose Up")
        docker_compose_up
        run_docker ps
        ;;
    "Docker Compose Rebuild (no-cache)")
        docker_compose_rebuild
        run_docker ps
        ;;
    "Docker Compose Down")
        docker_compose_down
        ;;
    "Docker PS")
        run_docker ps
        ;;
    "Goto Bash")
        CONTAINER_NAME="${ENV}_${APP_NAME}_php"
        if [ "$(run_docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo false)" = "true" ]; then
            display "info" "Opening shell as appuser in ${CONTAINER_NAME}"
            run_docker exec -u appuser -it "$CONTAINER_NAME" bash
        else
            display "error" "Container ${CONTAINER_NAME} is not running"
        fi
        ;;
    "Delete All Unused Docker Images")
        prune_unused_docker_images
        ;;
    "Set Swap Memory")
        setup_swap_memory
        ;;
    "Create NGINX Server Block")
        set_up_host_machine_nginx
        ;;
    "Delete NGINX Server Block")
        remove_host_machine_nginx
        ;;
    "Install Lets Encrypt SSL Certificate")
        install_ssl_certificate
        ;;
    "Quit"|"")
        display "info" "Bye."
        ;;
    *)
        display "error" "Unknown option: ${selected_automation}"
        exit 1
        ;;
esac
