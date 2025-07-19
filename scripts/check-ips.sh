#!/bin/bash

# Function to get container IP
get_container_ip() {
    docker inspect $1 --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null
}

# Check if containers are running
if ! docker ps --format '{{.Names}}' | grep -q "mongo1\|mongo2\|mongo3"; then
    echo "❌ MongoDB containers are not running. Please start them first with: docker compose up -d" >&2
    exit 1
fi

# Get current IPs
MONGO1_IP=$(get_container_ip mongo1)
MONGO2_IP=$(get_container_ip mongo2)
MONGO3_IP=$(get_container_ip mongo3)

# Verify we got IPs
if [[ -z "$MONGO1_IP" || -z "$MONGO2_IP" || -z "$MONGO3_IP" ]]; then
    echo "❌ Could not get all container IPs. Make sure containers are running." >&2
    exit 1
fi

# Output only the hosts file entries
echo "$MONGO1_IP mongo1"
echo "$MONGO2_IP mongo2"
echo "$MONGO3_IP mongo3"
