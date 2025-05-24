#!/bin/bash

CONFIG_FILE="$(dirname "$0")/vpn.conf"
PID_FILE="/var/run/vpn.pid"
REDSOCKS_CONF="/tmp/redsocks_vpn.conf"
IPTABLES_BACKUP="/tmp/iptables_vpn.backup"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Require root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run the script as root"
    exit 1
fi

# Install dependencies
install_deps() {
    echo "Installing dependencies..."
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y sshpass redsocks netcat-openbsd
    elif command -v yum &> /dev/null; then
        yum install -y sshpass redsocks nc
    elif command -v dnf &> /dev/null; then
        dnf install -y sshpass redsocks nc
    else
        echo "Error: Unsupported package manager"
        exit 1
    fi
}

# Setup alias and config
setup() {
    # Verify sudo user
    if [ -z "$SUDO_USER" ]; then
        echo "Error: Setup must be run with 'sudo' from a regular user account!"
        exit 1
    fi

    # Create config from example
    if [ ! -f "$CONFIG_FILE" ]; then
        if [ -f "${SCRIPT_DIR}/vpn.conf.example" ]; then
            cp "${SCRIPT_DIR}/vpn.conf.example" "$CONFIG_FILE"
            echo "Created config file from example: $CONFIG_FILE"
            echo "Edit the config file before starting the VPN"
        else
            echo "Error: vpn.conf.example not found in $SCRIPT_DIR"
            exit 1
        fi
    fi

    # Get user's home directory
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    BASH_RC="${USER_HOME}/.bashrc"
    
    # Add alias to user's .bashrc
    local alias_line="alias xvpn='sudo $SCRIPT_DIR/vpn.sh'"
    if ! grep -qF "$alias_line" "$BASH_RC"; then
        echo -e "\n# VPN Alias" >> "$BASH_RC"
        echo "$alias_line" >> "$BASH_RC"
        echo "Added alias to $BASH_RC"
        
        # Apply changes for current session if possible
        if [ -n "$BASH_VERSION" ] && [ -t 0 ]; then
            su - "$SUDO_USER" -c "source '$BASH_RC'"
            echo "Updated current user's environment"
        else
            echo "To apply changes immediately, run:"
            echo "  source $BASH_RC"
        fi
    else
        echo "Alias already exists in $BASH_RC"
    fi

    echo "Setup completed successfully"
}

# Dependency check
check_deps() {
    for cmd in sshpass redsocks nc; do
        if ! command -v $cmd &>/dev/null; then
            read -p "$cmd is missing. Install dependencies? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                install_deps
            else
                echo "Error: Dependencies not satisfied"
                exit 1
            fi
        fi
    done
}

# Load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Configuration file $CONFIG_FILE not found"
        exit 1
    fi
    source "$CONFIG_FILE"
    
    # Validate configuration
    for var in HOST PORT USER PASSWORD; do
        if [ -z "${!var}" ]; then
            echo "Error: $var not specified in config"
            exit 1
        fi
    done
}

# Free occupied ports
free_port() {
    lsof -ti :$1 | xargs -r kill -9
}

# Cleanup resources
cleanup() {
    echo "Performing cleanup..."
    
    # Stop SSH process
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            kill -9 $pid
            echo "Stopped SSH process $pid"
        fi
        rm -f "$PID_FILE"
    fi

    # Restore iptables
    if [ -f "$IPTABLES_BACKUP" ]; then
        iptables-restore < "$IPTABLES_BACKUP"
        rm "$IPTABLES_BACKUP"
        echo "Restored iptables rules"
    fi

    # Stop redsocks
    if pgrep -f "redsocks -c $REDSOCKS_CONF" >/dev/null; then
        pkill -f "redsocks -c $REDSOCKS_CONF"
        echo "Stopped redsocks"
    fi
    rm -f "$REDSOCKS_CONF"

    # Clean NAT chain
    if iptables -t nat -L REDSOCKS &>/dev/null; then
        iptables -t nat -F REDSOCKS
        iptables -t nat -X REDSOCKS
        echo "Cleaned iptables chain"
    fi

    echo "Cleanup completed"
}

# Start VPN connection
start_vpn() {
    check_deps
    load_config

    # Check for existing process
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            echo "VPN is already running (PID $pid)"
            return 1
        else
            rm -f "$PID_FILE"
        fi
    fi

    # Free ports
    free_port 1080
    free_port 12345

    # Start SSH tunnel
    echo "Connecting to $USER@$HOST:$PORT..."
    if ! sshpass -p "$PASSWORD" \
        ssh -o StrictHostKeyChecking=no \
            -D 1080 \
            -p "$PORT" \
            "$USER@$HOST" \
            -CNf; then
        echo "Connection failed!"
        return 1
    fi
    echo $! > "$PID_FILE"

    # Wait for port
    echo -n "Waiting for SOCKS5 port..."
    timeout 10 bash -c "while ! nc -z localhost 1080; do sleep 1; done"
    if [ $? -ne 0 ]; then
        echo " Timeout!"
        cleanup
        return 1
    fi
    echo " Ready"

    # Create redsocks config
    cat <<EOF > $REDSOCKS_CONF
base {
    log_info = on;
    daemon = on;
    redirector = iptables;
}
redsocks {
    local_ip = 0.0.0.0;
    local_port = 12345;
    ip = 127.0.0.1;
    port = 1080;
    type = socks5;
}
EOF

    # Start redsocks
    if ! redsocks -c $REDSOCKS_CONF; then
        echo "Failed to start redsocks!"
        cleanup
        return 1
    fi

    # Backup iptables
    iptables-save > $IPTABLES_BACKUP

    # Configure iptables rules
    iptables -t nat -N REDSOCKS 2>/dev/null
    iptables -t nat -F REDSOCKS

    for net in 0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4; do
        iptables -t nat -A REDSOCKS -d $net -j RETURN
    done

    iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345
    iptables -t nat -A OUTPUT -p tcp -j REDSOCKS

    echo "VPN started successfully (PID $(cat "$PID_FILE"))"
}

# Stop VPN connection
stop_vpn() {
    if [ ! -f "$PID_FILE" ]; then
        echo "VPN is not running"
        return 1
    fi
    cleanup
}

# Command handling
case "$1" in
    start)
        start_vpn
        ;;
    stop)
        stop_vpn
        ;;
    setup)
        setup
        ;;
    *)
        echo "Usage: $0 {start|stop|setup}"
        echo "Commands:"
        echo "  start   - Start VPN connection"
        echo "  stop    - Stop VPN connection"
        echo "  setup   - Initial setup (run first)"
        exit 1
        ;;
esac