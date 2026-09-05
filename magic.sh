#!/bin/bash
set -euo pipefail

source ./bash/utility.sh
source ./bash/docker.sh
source ./bash/nginx.sh
source ./bash/certbot.sh

read_env_file

automation_options=(
    "Install Docker & Docker Compose"           #0
    "Docker Compose Up"                         #1
    "Docker Compose Rebuild (no-cache)"         #2
    "Docker Compose Down"                       #3
    "Docker PS"                                 #4
    "Goto Bash"                                 #5
    "Delete All Unused Docker Images"           #6
    "Set Swap Memory"                           #7
    "Create NGINX Server Block"                 #8
    "Delete NGINX Server Block"                 #9
    "Install Lets Encrypt SSL Certificate"      #10
    "Quit"                                      #11
)

show_heading "Select Your Automation Option: "
selected_automation=$(get_selection "${automation_options[@]}")

if [ "$selected_automation" = "${automation_options[0]}" ]; then
    install_docker_and_compose
elif [ "$selected_automation" = "${automation_options[1]}" ]; then
    docker_compose_up
    run_docker ps
elif [ "$selected_automation" = "${automation_options[2]}" ]; then
    docker_compose_rebuild
    run_docker ps
elif [ "$selected_automation" = "${automation_options[3]}" ]; then
    docker_compose_down
elif [ "$selected_automation" = "${automation_options[4]}" ]; then
    run_docker ps
elif [ "$selected_automation" = "${automation_options[5]}" ]; then
    CONTAINER_NAME="${ENV}_${APP_NAME}_php"

    if [ "$(run_docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo false)" = "true" ]; then
        # Same user as PHP-FPM workers / queue / cron (uid 1000) — safe for artisan, composer, npm
        run_docker exec -u appuser -it "$CONTAINER_NAME" bash
    else
        echo "Error: Container $CONTAINER_NAME is not running"
    fi
elif [ "$selected_automation" = "${automation_options[6]}" ]; then
    prune_unused_docker_images
elif [ "$selected_automation" = "${automation_options[7]}" ]; then
    setup_swap_memory
elif [ "$selected_automation" = "${automation_options[8]}" ]; then
    set_up_host_machine_nginx
elif [ "$selected_automation" = "${automation_options[9]}" ]; then
    remove_host_machine_nginx
elif [ "$selected_automation" = "${automation_options[10]}" ]; then
    install_ssl_certificate
fi
