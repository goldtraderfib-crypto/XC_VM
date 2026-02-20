#!/bin/bash

# XC_VM IPTV Server Start Script
# This script starts the XC_VM IPTV panel services

SCRIPT=/home/xc_vm

echo "Starting XC_VM IPTV Server..."

# Set proper permissions first
echo "Setting permissions..."
sudo chmod -R 755 $SCRIPT/bin/
sudo chmod +x $SCRIPT/bin/nginx/sbin/nginx
sudo chmod +x $SCRIPT/bin/nginx_rtmp/sbin/nginx_rtmp
sudo chmod +x $SCRIPT/bin/php/bin/php
sudo chmod +x $SCRIPT/bin/redis/redis-server
sudo chmod +x $SCRIPT/bin/daemons.sh
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx/logs
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx_rtmp/logs
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx/client_body_temp
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx/fastcgi_temp
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx/proxy_temp
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx/scgi_temp
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx/uwsgi_temp
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx_rtmp/client_body_temp
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx_rtmp/fastcgi_temp
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx_rtmp/proxy_temp
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx_rtmp/scgi_temp
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/nginx_rtmp/uwsgi_temp
sudo mkdir -p $SCRIPT/bin/php/var/log $SCRIPT/bin/php/var/run $SCRIPT/bin/php/sockets
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/php/var
sudo chown -R xc_vm:xc_vm $SCRIPT/bin/php/sockets
sudo chmod 755 $SCRIPT/bin/php/sockets
sudo chown -R xc_vm:xc_vm /sys/class/net 2>/dev/null
sudo chown -R xc_vm:xc_vm $SCRIPT/content/streams 2>/dev/null
sudo chown -R xc_vm:xc_vm $SCRIPT/tmp 2>/dev/null

# Check if already running
pids=$(pgrep -u xc_vm nginx 2>/dev/null | wc -l)
if [ "$pids" != "0" ]; then
    echo "XC_VM is already running"
    echo "To stop it, run: sudo killall -u xc_vm"
else
    # Start Redis/KeyDB (skip if no config)
    if [ -f $SCRIPT/bin/redis/redis.conf ] && [ -f $SCRIPT/bin/redis/redis-server ]; then
        echo "Starting Redis (KeyDB)..."
        sudo -u xc_vm $SCRIPT/bin/redis/redis-server $SCRIPT/bin/redis/redis.conf 2>/dev/null
    fi

    # Start Nginx (needs root for port 80)
    echo "Starting Nginx..."
    sudo $SCRIPT/bin/nginx/sbin/nginx

    # Start Nginx RTMP (needs root for RTMP port)
    echo "Starting Nginx RTMP..."
    sudo $SCRIPT/bin/nginx_rtmp/sbin/nginx_rtmp

    # Start daemons
    echo "Starting daemons..."
    sudo -u xc_vm $SCRIPT/bin/daemons.sh 2>/dev/null

    # Run startup PHP script
    echo "Running startup scripts..."
    sudo $SCRIPT/bin/php/bin/php $SCRIPT/includes/cli/startup.php 2>/dev/null

    # Start background PHP processes
    echo "Starting background processes..."
    sudo -u xc_vm $SCRIPT/bin/php/bin/php $SCRIPT/includes/cli/signals.php >/dev/null 2>/dev/null &
    sudo -u xc_vm $SCRIPT/bin/php/bin/php $SCRIPT/includes/cli/watchdog.php >/dev/null 2>/dev/null &
    sudo -u xc_vm $SCRIPT/bin/php/bin/php $SCRIPT/includes/cli/queue.php >/dev/null 2>/dev/null &

    if [ -f $SCRIPT/includes/cli/cache_handler.php ]; then
        sudo -u xc_vm $SCRIPT/bin/php/bin/php $SCRIPT/includes/cli/cache_handler.php >/dev/null 2>/dev/null &
    fi

    if [ -f $SCRIPT/includes/cli/connection_sync.php ]; then
        sudo -u xc_vm $SCRIPT/bin/php/bin/php $SCRIPT/includes/cli/connection_sync.php >/dev/null 2>/dev/null &
    fi
fi

# Get the access code from nginx config
ACCESS_CODE=""
CODES_DIR="$SCRIPT/bin/nginx/conf/codes"
if [ -d "$CODES_DIR" ]; then
    for conf_file in "$CODES_DIR"/*.conf; do
        if [ -f "$conf_file" ]; then
            code_name=$(basename "$conf_file" .conf)
            if [ "$code_name" != "template" ]; then
                ACCESS_CODE="$code_name"
                break
            fi
        fi
    done
fi

echo ""
echo "========================================"
echo "XC_VM IPTV Server Started Successfully!"
echo "========================================"
echo ""

# Check if running in GitHub Codespaces
if [ -n "$CODESPACE_NAME" ] && [ -n "$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN" ]; then
    echo "Running in GitHub Codespaces"
    echo ""
    
    # Make ports public
    echo "Making ports public..."
    gh codespace ports visibility 80:public 443:public -c $CODESPACE_NAME 2>/dev/null || true
    
    echo ""
    echo "Services running on:"
    echo "  - HTTP:  https://${CODESPACE_NAME}-80.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    echo "  - HTTPS: https://${CODESPACE_NAME}-443.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    echo "  - RTMP:  rtmp://${CODESPACE_NAME}-8880.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    echo ""
    
    if [ -n "$ACCESS_CODE" ]; then
        echo "========================================"
        echo "XC_VM Admin Panel:"
        echo "  https://${CODESPACE_NAME}-80.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/${ACCESS_CODE}/"
        echo "========================================"
        echo ""
    fi
else
    # Get server IP for non-Codespaces environments
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="localhost"
    fi
    
    echo "Services running on:"
    echo "  - HTTP:  http://$SERVER_IP:80"
    echo "  - HTTPS: https://$SERVER_IP:443"
    echo "  - RTMP:  rtmp://$SERVER_IP:8880"
    echo ""
    
    if [ -n "$ACCESS_CODE" ]; then
        echo "========================================"
        echo "XC_VM Admin Panel:"
        echo "  http://$SERVER_IP/$ACCESS_CODE/"
        echo "========================================"
        echo ""
    fi
fi

echo "To stop the server, run: sudo killall nginx nginx_rtmp php-fpm"
echo "To view status, run: sudo $SCRIPT/status"
