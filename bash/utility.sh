#!/bin/bash

function get_login_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
        echo "$SUDO_USER"
    elif [ -n "${USER:-}" ] && [ "${USER}" != "root" ]; then
        echo "$USER"
    else
        id -un
    fi
}

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
    printf '%s\n' "$selected_value"
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
    local type=$1
    local message=$2

    case "$type" in
        danger|error)
            echo -e "\033[0;31m$message\033[0m"
            ;;
        success)
            echo -e "\033[0;32m$message\033[0m"
            ;;
        warning)
            echo -e "\033[0;33m$message\033[0m"
            ;;
        info)
            echo -e "\033[0;34m$message\033[0m"
            ;;
        *)
            echo "$message"
            ;;
    esac
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
    if [ ! -f .env ]; then
        display "danger" ".env file not found!"
        exit 1
    fi

    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
}

# Function to set up swap memory
function setup_swap_memory() {
    local SWAP_SIZE
    local SWAP_FILE="/swapfile"
    local SWAPPINESS=10

    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        display "error" "This function requires passwordless sudo (the EC2 login user, e.g. ubuntu, normally has this)."
        return 1
    fi

    while true; do
        read -p "Enter the swap size (e.g., 1G, 2G, 512M): " SWAP_SIZE
        if [[ $SWAP_SIZE =~ ^[0-9]+[MG]$ ]]; then
            break
        else
            display "error" "Invalid input. Please enter the swap size in the format like '2G' for 2 GB or '512M' for 512 MB."
        fi
    done

    if sudo swapon --show | grep -q "${SWAP_FILE}"; then
        display "warning" "Swap space is already enabled."
        return 0
    fi

    local unit="${SWAP_SIZE: -1}"
    local size_num="${SWAP_SIZE%?}"
    local required_mb
    if [ "$unit" = "G" ]; then
        required_mb=$((size_num * 1024))
    else
        required_mb=$size_num
    fi

    local available_mb
    available_mb=$(df -BM / | awk 'NR==2 {print $4}' | sed 's/M//')
    if [ "$available_mb" -lt "$required_mb" ]; then
        display "error" "Not enough disk space. Required: ${required_mb}M, Available: ${available_mb}M"
        return 1
    fi

    if [ -f "$SWAP_FILE" ]; then
        sudo swapoff "$SWAP_FILE" 2>/dev/null || true
        sudo rm -f "$SWAP_FILE"
    fi

    display "info" "Creating swap file of size ${SWAP_SIZE}..."
    if ! sudo fallocate -l "$SWAP_SIZE" "$SWAP_FILE"; then
        display "info" "fallocate failed, trying dd method..."
        if ! sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$required_mb"; then
            display "error" "Failed to create swap file"
            return 1
        fi
    fi

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

    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
        if [ $? -ne 0 ]; then
            display "error" "Failed to update /etc/fstab"
            return 1
        fi
    fi

    if ! sudo sysctl vm.swappiness=$SWAPPINESS; then
        display "warning" "Failed to set immediate swappiness"
    fi

    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=$SWAPPINESS" | sudo tee -a /etc/sysctl.conf >/dev/null
        if [ $? -ne 0 ]; then
            display "warning" "Failed to set permanent swappiness"
        fi
    fi

    if sudo swapon --show | grep -q "$SWAP_FILE"; then
        display "success" "Swap setup complete! Size: ${SWAP_SIZE}, Swappiness: ${SWAPPINESS}"
        return 0
    else
        display "error" "Swap setup verification failed"
        return 1
    fi
}
