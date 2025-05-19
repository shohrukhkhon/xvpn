#!/bin/bash

# This script must be run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root to configure network settings."
    exit 1
fi

CONFIG_FILE="$(dirname "$0")/vpn.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found!"
    echo "Create a file with the following format:"
    echo "HOST=exaple.com"
    echo "PORT=22"
    echo "USER=user"
    echo "PASSWORD=your_password"
    exit 1
fi

if [ $(stat -c %a "$CONFIG_FILE") -ne 660 ]; then
    echo "Warning: Configuration file should have 660 permissions!"
    echo "Run manually: chmod 660 '$CONFIG_FILE'"
fi

source "$CONFIG_FILE"

for var in HOST PORT USER PASSWORD; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in configuration file!"
        exit 1
    fi
done

if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass is not installed. Please install it first:"
    echo "For Debian/Ubuntu: sudo apt-get install sshpass"
    exit 1
fi

if ! command -v redsocks &> /dev/null; then
    echo "Error: redsocks is not installed. Please install it first:"
    echo "For Debian/Ubuntu: sudo apt-get install redsocks"
    exit 1
fi

if ! command -v nc &> /dev/null; then
    echo "Error: netcat (nc) is not installed. Please install it."
    exit 1
fi

cleanup() {
    echo -e "\nRestoring original settings..."
    if [ -f "/tmp/iptables_$$.backup" ]; then
        iptables-restore < "/tmp/iptables_$$.backup"
        rm "/tmp/iptables_$$.backup"
    fi
    pkill -f "redsocks -c /tmp/redsocks_$$.conf"
    rm -f "/tmp/redsocks_$$.conf"
    echo "Cleanup completed."
}

trap cleanup EXIT INT TERM

configure_redsocks_and_iptables() {
    echo "Configuring redsocks and iptables..."
    REDSOCKS_CONF="/tmp/redsocks_$$.conf"
    cat <<EOF > $REDSOCKS_CONF
base {
    log_debug = off;
    log_info = on;
    log = "syslog";
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

    redsocks -c $REDSOCKS_CONF
    iptables-save > /tmp/iptables_$$.backup

    iptables -t nat -F
    iptables -t nat -N REDSOCKS

    iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A REDSOCKS -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A REDSOCKS -d 240.0.0.0/4 -j RETURN

    iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345
    iptables -t nat -A OUTPUT -p tcp -j REDSOCKS
}

main() {
    echo "Connecting to $USER@$HOST:$PORT..."
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
        -D 1080 \
        -p "$PORT" \
        "$USER@$HOST" \
        -C -N -v &
    SSH_PID=$!

    while ! nc -z localhost 1080; do
        sleep 1
    done

    configure_redsocks_and_iptables  # Removed parentheses here

    wait $SSH_PID
    if [ $? -ne 0 ]; then
        echo "Connection failed!"
        exit 1
    fi
}

main
