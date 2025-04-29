#!/bin/bash

    function get_selection() {
        local options=("$@")
        local selected_value=0
        PS3='Enter your choice: '

        select opt in "${options[@]}"
        do
            if [[ -n $opt ]]; then
                selected_value=$opt
                break
            fi
        done
        echo $selected_value
    }

    function handle_error() {
        local exit_code=$1
        local error_message=$2
        if [ $exit_code -ne 0 ]; then
            display "error" "Error: $error_message (Exit code: $exit_code)"
            exit $exit_code
        fi
    }

    function show_heading(){
        echo -e "\033[0;36m╔═══════════════════════════════════════════════════════════════════╗\033[0m"
        echo -e "\033[0;36m║ \033[0;32m=> $1\033[0;36m                                                       ║\033[0m"
        echo -e "\033[0;36m╚═══════════════════════════════════════════════════════════════════╝\033[0m"
    }

    function display(){
        local color_scheme=("danger" "success" "warning" "info")
        local type=$1
        local message=$2

        if [ "type" = "${color_scheme[0]}" ]; then
            echo -e "\033[0;31m$message\033[0m" #red
        elif [ "type" = "${color_scheme[1]}" ]; then
            echo -e "\033[0;32m$message\033[0m" #green
        elif [ "type" = "${color_scheme[2]}" ]; then
            echo -e "\033[0;33m$message\033[0m" #yellow
        elif [ "type" = "${color_scheme[3]}" ]; then
            echo -e "\033[0;34m$message\033[0m" #blue
        else
            echo "$message"
        fi
    }

    function get_user_choice() {
        local choice
        while true; do
            read -p "Please enter yes or no: " choice
            case "$choice" in
                [Yy][Ee][Ss]|[Yy])
                    return 0  # true
                    ;;
                [Nn][Oo]|[Nn])
                    return 1  # false
                    ;;
                *)
                    echo "Invalid input. Please enter yes or no."
                    ;;
            esac
        done
    }

    function read_env_file() {
        # Get the ENV from the .env file
        if [ -f .env ]; then
            source .env
        else
            display "danger" ".env file not found!"
            exit 1
        fi

        # Set the variables globally
        COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME
        APP_NAME=$APP_NAME
        ENV=$ENV
        CONTAINER_PORT=$CONTAINER_PORT
        HOST_URL=$HOST_URL
        HOST_PORT=$HOST_PORT
        ENABLE_CRON=$ENABLE_CRON
        ENABLE_JOBS=$ENABLE_JOBS
        PHP_VERSION=$PHP_VERSION
        PHP_MEMORY_LIMIT=$PHP_MEMORY_LIMIT
        PHP_UPLOAD_MAX_FILESIZE=$PHP_UPLOAD_MAX_FILESIZE
        PHP_POST_MAX_SIZE=$PHP_POST_MAX_SIZE
        PHP_MAX_EXECUTION_TIME=$PHP_MAX_EXECUTION_TIME
        ENABLE_MONGODB_EXTENSION=$ENABLE_MONGODB_EXTENSION
        ENABLE_MONGODB_EXTENSION_VERSION=$ENABLE_MONGODB_EXTENSION_VERSION
    }

    # Function to set up swap memory
    function setup_swap_memory() {
        # Add function description and parameters documentation
        local SWAP_SIZE
        local SWAP_FILE="/swapfile"
        local SWAPPINESS=10  # Make swappiness configurable

        # Validate root privileges first
        if [ "$EUID" -ne 0 ] && ! sudo -v; then
            display "error" "This function requires sudo privileges"
            return 1
        fi

        # Get and validate swap size input
        while true; do
            read -p "Enter the swap size (e.g., 1G, 2G, 512M): " SWAP_SIZE
            if [[ $SWAP_SIZE =~ ^[0-9]+[MG]$ ]]; then
                break
            else
                display "error" "Invalid input. Please enter the swap size in the format like '2G' for 2 GB or '512M' for 512 MB."
            fi
        done

        # Check if swap is already enabled
        if sudo swapon --show | grep -q "${SWAP_FILE}"; then
            display "warning" "Swap space is already enabled."
            return 0
        fi

        # Check available disk space before proceeding
        local REQUIRED_SPACE=$(echo "$SWAP_SIZE" | sed 's/[MG]//')
        local AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

        if [ "${SWAP_SIZE: -1}" = "G" ] && [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
            display "error" "Not enough disk space. Required: ${REQUIRED_SPACE}G, Available: ${AVAILABLE_SPACE}G"
            return 1
        fi

        # Create swap file with error handling
        display "info" "Creating swap file of size ${SWAP_SIZE}..."
        if ! sudo fallocate -l "$SWAP_SIZE" "$SWAP_FILE"; then
            display "info" "fallocate failed, trying dd method..."
            if ! sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$(echo "$SWAP_SIZE" | sed 's/[MG]//')"000"; then
                display "error" "Failed to create swap file"
                return 1
            fi
        fi

        # Set permissions and initialize swap
        if ! sudo chmod 600 "$SWAP_FILE"; then
            display "error" "Failed to set swap file permissions"
            return 1
        fi

        if ! sudo mkswap "$SWAP_FILE"; then
            display "error" "Failed to initialize swap file"
            return 1
        fi

        if ! sudo swapon "$SWAP_FILE"; then
            display "error" "Failed to enable swap"
            return 1
        fi

        # Update /etc/fstab if needed
        if ! grep -q "$SWAP_FILE" /etc/fstab; then
            echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
            if [ $? -ne 0 ]; then
                display "error" "Failed to update /etc/fstab"
                return 1
            fi
        fi

        # Configure swappiness
        if ! sudo sysctl vm.swappiness=$SWAPPINESS; then
            display "warning" "Failed to set immediate swappiness"
        fi

        if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
            echo "vm.swappiness=$SWAPPINESS" | sudo tee -a /etc/sysctl.conf >/dev/null
            if [ $? -ne 0 ]; then
                display "warning" "Failed to set permanent swappiness"
            fi
        fi

        # Verify setup
        if sudo swapon --show | grep -q "$SWAP_FILE"; then
            display "success" "Swap setup complete! Size: ${SWAP_SIZE}, Swappiness: ${SWAPPINESS}"
            return 0
        else
            display "error" "Swap setup verification failed"
            return 1
        fi
    }

