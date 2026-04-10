#!/bin/bash
set -euo pipefail

# ========================================================================
# VITAL GAMER - Enhanced Multi-VM Manager
# ========================================================================

# Function to display header
display_header() {
    clear
    cat << "EOF"
========================================================================
             __      _______ _______       _        
             \ \    / /_   _|__   __|/\   | |       
              \ \  / /  | |    | |  /  \  | |       
               \ \/ /   | |    | | / /\ \ | |       
                \  /   _| |_   | |/ ____ \| |____   
                 \/   |_____|  |_/_/    \_\______|  
                                                    
                      G  A  M  E  R                    
========================================================================
Sponsor By: VITAL GAMER Community
Authorized Lead: Mahin
========================================================================
EOF
    echo
}

# Function to display colored output
print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "INFO") echo -e "\033[1;34m[VITAL-INFO]\033[0m $message" ;;
        "WARN") echo -e "\033[1;33m[VITAL-WARN]\033[0m $message" ;;
        "ERROR") echo -e "\033[1;31m[VITAL-ERROR]\033[0m $message" ;;
        "SUCCESS") echo -e "\033[1;32m[VITAL-SUCCESS]\033[0m $message" ;;
        "INPUT") echo -e "\033[1;36m[VITAL-INPUT]\033[0m $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

# Function to validate input
validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "Must be a number"
                return 1
            fi
            ;;
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMm]$ ]]; then
                print_status "ERROR" "Must be a size with unit (e.g., 100G, 512M)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "Must be a valid port number (23-65535)"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_status "ERROR" "VM name can only contain letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "Username must start with a letter or underscore, and contain only letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
    esac
    return 0
}

# Function to check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "On Ubuntu/Debian, try: sudo apt install qemu-system cloud-image-utils wget"
        exit 1
    fi
}

# Function to cleanup temporary files
cleanup() {
    if [ -f "user-data" ]; then rm -f "user-data"; fi
    if [ -f "meta-data" ]; then rm -f "meta-data"; fi
}

# Function to get all VM configurations
get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

# Function to load VM configuration
load_vm_config() {
    local vm_name=$1
    local config_file="$VM_DIR/$vm_name.conf"
    
    if [[ -f "$config_file" ]]; then
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED
        
        source "$config_file"
        return 0
    else
        print_status "ERROR" "Configuration for VM '$vm_name' not found"
        return 1
    fi
}

# Function to save VM configuration
save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"
    
    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
EOF
    
    print_status "SUCCESS" "VITAL Config saved to $config_file"
}

# Function to create new VM
create_new_vm() {
    print_status "INFO" "Initializing VITAL VM setup..."
    
    # OS Selection
    print_status "INFO" "Select an OS for your VITAL Workspace:"
    local os_options=()
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        echo "  $i) $os"
        os_options[$i]="$os"
        ((i++))
    done
    
    while true; do
        read -p "$(print_status "INPUT" "Enter choice (1-${#OS_OPTIONS[@]}): ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#OS_OPTIONS[@]} ]; then
            local os="${os_options[$choice]}"
            IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$os]}"
            break
        else
            print_status "ERROR" "Invalid selection."
        fi
    done

    # Custom Inputs
    while true; do
        read -p "$(print_status "INPUT" "Enter VM name (default: $DEFAULT_HOSTNAME): ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"
        if validate_input "name" "$VM_NAME"; then
            if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
                print_status "ERROR" "VITAL VM '$VM_NAME' already exists"
            else
                break
            fi
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Enter hostname (default: $VM_NAME): ")" HOSTNAME
        HOSTNAME="${HOSTNAME:-$VM_NAME}"
        if validate_input "name" "$HOSTNAME"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Enter username (default: vital): ")" USERNAME
        USERNAME="${USERNAME:-vital}"
        if validate_input "username" "$USERNAME"; then
            break
        fi
    done

    while true; do
        read -s -p "$(print_status "INPUT" "Enter VITAL Password (default: vital123): ")" PASSWORD
        PASSWORD="${PASSWORD:-vital123}"
        echo
        if [ -n "$PASSWORD" ]; then
            break
        else
            print_status "ERROR" "Password cannot be empty"
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Disk size (default: 20G): ")" DISK_SIZE
        DISK_SIZE="${DISK_SIZE:-20G}"
        if validate_input "size" "$DISK_SIZE"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Memory in MB (default: 2048): ")" MEMORY
        MEMORY="${MEMORY:-2048}"
        if validate_input "number" "$MEMORY"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Number of CPUs (default: 2): ")" CPUS
        CPUS="${CPUS:-2}"
        if validate_input "number" "$CPUS"; then
            break
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "SSH Port (default: 2222): ")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"
        if validate_input "port" "$SSH_PORT"; then
            if ss -tln 2>/dev/null | grep -q ":$SSH_PORT "; then
                print_status "ERROR" "Port $SSH_PORT is in use"
            else
                break
            fi
        fi
    done

    while true; do
        read -p "$(print_status "INPUT" "Enable GUI mode? (y/n, default: n): ")" gui_input
        GUI_MODE=false
        gui_input="${gui_input:-n}"
        if [[ "$gui_input" =~ ^[Yy]$ ]]; then 
            GUI_MODE=true
            break
        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
            break
        else
            print_status "ERROR" "Answer y or n"
        fi
    done

    read -p "$(print_status "INPUT" "Additional port forwards (e.g., 8080:80, Enter for none): ")" PORT_FORWARDS

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"

    setup_vm_image
    save_vm_config
}

# Function to setup VM image
setup_vm_image() {
    print_status "INFO" "Preparing VITAL System Image..."
    mkdir -p "$VM_DIR"
    
    if [[ -f "$IMG_FILE" ]]; then
        print_status "INFO" "Image found. Skipping download."
    else
        print_status "INFO" "Downloading VITAL Core from $IMG_URL..."
        if ! wget --progress=bar:force "$IMG_URL" -O "$IMG_FILE.tmp"; then
            print_status "ERROR" "Download failed"
            exit 1
        fi
        mv "$IMG_FILE.tmp" "$IMG_FILE"
    fi
    
    qemu-img resize "$IMG_FILE" "$DISK_SIZE" &>/dev/null || true

    # cloud-init configuration
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
EOF

    cat > meta-data <<EOF
instance-id: vital-$VM_NAME
local-hostname: $HOSTNAME
EOF

    if ! cloud-localds "$SEED_FILE" user-data meta-data; then
        print_status "ERROR" "Cloud-init failed"
        exit 1
    fi
    
    print_status "SUCCESS" "VITAL VM '$VM_NAME' is ready."
}

# Function to start a VM
start_vm() {
    local vm_name=$1
    if load_vm_config "$vm_name"; then
        print_status "INFO" "Launching VITAL VM: $vm_name"
        print_status "SUCCESS" "Connection: ssh -p $SSH_PORT $USERNAME@localhost"
        
        local qemu_cmd=(
            qemu-system-x86_64
            -enable-kvm
            -m "$MEMORY"
            -smp "$CPUS"
            -cpu host
            -drive "file=$IMG_FILE,format=qcow2,if=virtio"
            -drive "file=$SEED_FILE,format=raw,if=virtio"
            -boot order=c
            -device virtio-net-pci,netdev=n0
            -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
        )

        if [[ -n "$PORT_FORWARDS" ]]; then
            IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
            for forward in "${forwards[@]}"; do
                IFS=':' read -r host_port guest_port <<< "$forward"
                qemu_cmd+=(-device "virtio-net-pci,netdev=n${#qemu_cmd[@]}")
                qemu_cmd+=(-netdev "user,id=n${#qemu_cmd[@]},hostfwd=tcp::$host_port-:$guest_port")
            done
        fi

        if [[ "$GUI_MODE" == true ]]; then
            qemu_cmd+=(-vga virtio -display gtk,gl=on)
        else
            qemu_cmd+=(-nographic -serial mon:stdio)
        fi

        qemu_cmd+=(
            -device virtio-ballon-pci
            -object rng-random,filename=/dev/urandom,id=rng0
            -device virtio-rng-pci,rng=rng0
        )

        print_status "INFO" "VITAL Engine Running..."
        "${qemu_cmd[@]}"
        print_status "INFO" "VITAL VM shut down"
    fi
}

# Function to delete a VM
delete_vm() {
    local vm_name=$1
    print_status "WARN" "DANGER: Permanent deletion of VITAL VM '$vm_name'!"
    read -p "$(print_status "INPUT" "Confirm? (y/N): ")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if load_vm_config "$vm_name"; then
            rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf"
            print_status "SUCCESS" "VITAL VM wiped."
        fi
    fi
}

# Function to show VM info
show_vm_info() {
    local vm_name=$1
    if load_vm_config "$vm_name"; then
        echo
        print_status "INFO" "VITAL System Stats: $vm_name"
        echo "=========================================="
        echo "OS: $OS_TYPE"
        echo "VITAL Host: $HOSTNAME"
        echo "VITAL User: $USERNAME"
        echo "SSH Port: $SSH_PORT"
        echo "Resource: $CPUS Cores / $MEMORY MB"
        echo "Storage: $DISK_SIZE"
        echo "Created: $CREATED"
        echo "=========================================="
        echo
        read -p "$(print_status "INPUT" "Press Enter to return...")"
    fi
}

is_vm_running() {
    local vm_name=$1
    pgrep -f "qemu-system-x86_64.*$vm_name" >/dev/null && return 0 || return 1
}

# Stop VM function
stop_vm() {
    local vm_name=$1
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            print_status "INFO" "Terminating VITAL VM: $vm_name"
            pkill -f "qemu-system-x86_64.*$IMG_FILE"
            sleep 2
            print_status "SUCCESS" "VITAL VM stopped"
        else
            print_status "INFO" "VM is not active"
        fi
    fi
}

# Main menu function
main_menu() {
    while true; do
        display_header
        local vms=($(get_vm_list))
        local vm_count=${#vms[@]}
        
        if [ $vm_count -gt 0 ]; then
            print_status "INFO" "VITAL Dashboard - Active/Saved VMs:"
            for i in "${!vms[@]}"; do
                local status="Offline"
                is_vm_running "${vms[$i]}" && status="ONLINE"
                printf "  %2d) %s [%s]\n" $((i+1)) "${vms[$i]}" "$status"
            done
            echo
        fi
        
        echo "VITAL GAMER COMMAND CENTER:"
        echo "  1) Deploy New VITAL VM"
        if [ $vm_count -gt 0 ]; then
            echo "  2) Boot VITAL VM"
            echo "  3) Shut Down VITAL VM"
            echo "  4) View VITAL System Info"
            echo "  5) Wipe VITAL VM"
        fi
        echo "  0) Exit Console"
        echo
        
        read -p "$(print_status "INPUT" "Enter Command: ")" choice
        
        case $choice in
            1) create_new_vm ;;
            2) 
                read -p "VM Number: " vm_num
                [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -le $vm_count ] && start_vm "${vms[$((vm_num-1))]}"
                ;;
            3)
                read -p "VM Number: " vm_num
                [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -le $vm_count ] && stop_vm "${vms[$((vm_num-1))]}"
                ;;
            4)
                read -p "VM Number: " vm_num
                [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -le $vm_count ] && show_vm_info "${vms[$((vm_num-1))]}"
                ;;
            5)
                read -p "VM Number: " vm_num
                [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -le $vm_count ] && delete_vm "${vms[$((vm_num-1))]}"
                ;;
            0) print_status "INFO" "Exiting VITAL Console..."; exit 0 ;;
        esac
        read -p "$(print_status "INPUT" "Return to menu...")"
    done
}

trap cleanup EXIT
check_dependencies
VM_DIR="${VM_DIR:-$HOME/vital_vms}"
mkdir -p "$VM_DIR"

declare -A OS_OPTIONS=(
    ["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|vital-u22|vital|vital123"
    ["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|vital-d12|vital|vital123"
)

main_menu
