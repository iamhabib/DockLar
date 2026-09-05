#!/bin/bash
source ./bash/utility.sh
source ./bash/docker.sh
source ./bash/nginx.sh
source ./bash/certbot.sh

read_env_file

automation_options=(
    "Install Docker & Docker Compose"           #0
    "Docker Compose Up"                         #1
    "Docker Compose Down"                       #2
    "Docker PS"                                 #3
    "Goto Bash"                                 #4
    "Delete All Unused Docker Images"           #5
    "Set Swap Memory"                           #6
    "Create NGINX Server Block"                 #7
    "Delete NGINX Server Block"                 #8
    "Install Lets Encrypt SSL Certificate"      #9
    "Quit"                                      #10
)

show_heading "Select Your Automation Option: "
selected_automation=$(get_selection "${automation_options[@]}")

if [ "$selected_automation" = "${automation_options[0]}" ]; then
    install_docker_and_compose
elif [ "$selected_automation" = "${automation_options[1]}" ]; then

    display "info" "ENV File: ===================START================"
    cat .env
    display "info" "ENV File: ====================END================="

    docker_compose_up

    run_docker ps

elif [ "$selected_automation" = "${automation_options[2]}" ]; then
    docker_compose_down
elif [ "$selected_automation" = "${automation_options[3]}" ]; then
    run_docker ps
elif [ "$selected_automation" = "${automation_options[4]}" ]; then

    CONTAINER_NAME="${ENV}_${APP_NAME}_php"

    if [ "$(run_docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)" = "true" ]; then
        run_docker exec -u 0 -it "$CONTAINER_NAME" bash
    else
        echo "Error: Container $CONTAINER_NAME is not running"
    fi
elif [ "$selected_automation" = "${automation_options[5]}" ]; then
    prune_unused_docker_images
elif [ "$selected_automation" = "${automation_options[6]}" ]; then
    setup_swap_memory
elif [ "$selected_automation" = "${automation_options[7]}" ]; then
    set_up_host_machine_nginx
elif [ "$selected_automation" = "${automation_options[8]}" ]; then
    remove_host_machine_nginx
elif [ "$selected_automation" = "${automation_options[9]}" ]; then
    install_ssl_certificate
fi
