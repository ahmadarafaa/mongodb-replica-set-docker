#!/bin/bash

# MongoDB Replica Set Task Installation Script
# This script installs and sets up a MongoDB replica set cluster

# Load environment variables from .env file if it exists
if [[ -f ".env" ]]; then
    export $(grep -v '^#' .env | xargs)
fi

# Set default MongoDB version if not specified
MONGO_VERSION=${MONGO_VERSION:-6.0}

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_warning() {
    echo "[WARNING] $1"
}

log_error() {
    echo "[ERROR] $1"
}

# Progress indicator functions
show_progress() {
    local duration=$1
    local message="$2"
    local end_time=$((SECONDS + duration))
    
    printf "$message"
    while [ $SECONDS -lt $end_time ]; do
        printf "."
        sleep 1
    done
    printf " done\n"
}

show_step_progress() {
    local step=$1
    local total=$2
    local message="$3"
    
    printf "Step %d/%d: %s\n" $step $total "$message"
}


# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker service."
        exit 1
    fi
    
    # Check if mongosh is available
    if ! command -v mongosh &> /dev/null; then
        log_warning "mongosh is not installed. Consider installing it for better MongoDB interaction."
    fi
    
    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        log_warning "OpenSSL is not installed. Will use existing keyfile if available."
    else
        log_success "OpenSSL found - will generate new secure keyfile"
    fi
    
    log_success "Prerequisites check completed"
}

# Clean up existing containers and volumes
cleanup_existing() {
    log_info "Cleaning up existing MongoDB containers and volumes..."
    
    # Always start fresh from template to avoid authentication conflicts
    if [[ -f "docker-compose.template.yml" ]]; then
        log_info "Copying fresh docker-compose.yml from template..."
        cp docker-compose.template.yml docker-compose.yml
    else
        log_warning "No template found, using existing docker-compose.yml"
    fi
    
    # Stop and remove existing containers
    show_progress 5 "Stopping existing containers..."
    docker compose down -v > /dev/null 2>&1 || true
    
    # Remove any existing containers with the same names
    containers=("mongo1" "mongo2" "mongo3" "mongo-setup")
    for container in "${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^$container$" 2>/dev/null; then
            docker rm -f "$container" > /dev/null 2>&1 || true
        fi
    done
    
    # Remove any detached volumes (both old prefixed and new static names)
    volumes=("mongodb-task_mongo1_data" "mongodb-task_mongo2_data" "mongodb-task_mongo3_data" "config_mongo1_data" "config_mongo2_data" "config_mongo3_data" "mongo1_data" "mongo2_data" "mongo3_data")
    for volume in "${volumes[@]}"; do
        if docker volume ls --format '{{.Name}}' | grep -q "^$volume$" 2>/dev/null; then
            docker volume rm "$volume" > /dev/null 2>&1 || true
        fi
    done
    
    log_success "Cleanup completed"
}

# Generate MongoDB keyfile for replica set authentication
generate_keyfile() {
    log_info "Setting up MongoDB keyfile for authentication..."
    
    # Create keyfile directory if it doesn't exist
    mkdir -p config/keyfile
    
    # Generate new keyfile if openssl is available, otherwise use existing one
    if command -v openssl &> /dev/null; then
        show_progress 3 "Generating new secure keyfile with OpenSSL..."
        openssl rand -base64 756 > config/keyfile/keyfile 2>/dev/null
        chmod 600 config/keyfile/keyfile
        log_success "New secure keyfile generated"
    elif [[ -f "config/keyfile/keyfile" ]]; then
        log_info "OpenSSL not available - using existing keyfile"
        chmod 600 config/keyfile/keyfile
        log_success "Existing keyfile configured"
    else
        log_error "No OpenSSL available and no existing keyfile found. Cannot proceed."
        exit 1
    fi
    
    log_success "Keyfile authentication setup completed"
}

# Create external volumes with static names
create_external_volumes() {
    log_info "Creating external volumes with static names..."
    
    volumes=("mongo1_data" "mongo2_data" "mongo3_data")
    for volume in "${volumes[@]}"; do
        if ! docker volume ls --format '{{.Name}}' | grep -q "^$volume$" 2>/dev/null; then
            docker volume create "$volume" > /dev/null 2>&1
            log_success "Created volume: $volume"
        else
            log_info "Volume already exists: $volume"
        fi
    done
    
    log_success "External volumes ready"
}

# Start the MongoDB cluster
start_cluster() {
    echo ""
    log_info "Starting MongoDB replica set cluster..."
    
    # Create the network if it doesn't exist
    if ! docker network ls --format '{{.Name}}' | grep -q '^mongo-cluster$'; then
        log_info "Creating mongo-cluster network..."
        docker network create mongo-cluster > /dev/null 2>&1
    fi
    
    # Step 1: Start containers without authentication initially
    show_step_progress 1 5 "Starting containers without authentication..."
    if ! docker compose up -d > /dev/null 2>&1; then
        printf "\n"
        log_error "Failed to start containers. Check Docker and docker-compose.yml"
        return 1
    fi
    printf "\n"
    log_success "Containers started successfully"
    
    # Step 2: Wait for containers to initialize
    show_step_progress 2 5 "Waiting for MongoDB instances to initialize..."
    printf "\n"
    show_progress 30 "Initializing MongoDB instances..."
    log_success "MongoDB instances are ready"
    
    # Step 3: Initialize replica set and create users
    show_step_progress 3 5 "Setting up replica set and users..."
    
    # Use the dedicated setup script that handles localhost exception properly
    if docker run --rm --network mongo-cluster -v $(pwd)/config/init:/scripts mongo:${MONGO_VERSION} bash /scripts/setup-replica-set-working.sh > /tmp/setup.log 2>&1; then
        printf "\n"
        log_success "Replica set and users configured successfully"
    else
        printf "\n"
        log_error "Replica set setup failed. Check /tmp/setup.log for details"
        log_error "Setup log contents:"
        cat /tmp/setup.log | tail -20
        return 1
    fi
    
    # Step 4: Enable authentication by restarting containers
    show_step_progress 4 5 "Enabling authentication..."
    docker compose down > /dev/null 2>&1
    
    # Update docker-compose to enable auth
    sed -i 's/--quiet$/--quiet --auth --keyFile \/opt\/keyfile\/keyfile/' docker-compose.yml
    
    # Restart with authentication
    if ! docker compose up -d > /dev/null 2>&1; then
        printf "\n"
        log_error "Failed to restart containers with authentication"
        return 1
    fi
    printf "\n"
    log_success "Authentication enabled successfully"
    
    # Step 5: Final verification
    show_step_progress 5 5 "Running final health check..."
    printf "\n"
    show_progress 10 "Verifying cluster health..."
    
    if docker run --rm --network mongo-cluster -v $(pwd)/scripts:/scripts mongo:${MONGO_VERSION} bash /scripts/test-cluster.sh > /dev/null 2>&1; then
        printf "\n"
        log_success "Authenticated cluster is healthy and ready"
    else
        printf "\n"
        log_warning "Cluster health check had issues, but cluster should be functional"
    fi
    printf "\n"
}

# Configure network (update /etc/hosts)
configure_network() {
    log_info "Configuring network settings..."
    
    # Get container IPs
    show_progress 2 "Getting container IP addresses..."
    ./scripts/check-ips.sh 2>/dev/null
    
    echo ""
    log_warning "IMPORTANT: Update your /etc/hosts file manually!"
    log_warning "Copy the IP mappings shown above and add them to /etc/hosts"
    echo ""
}

# Display connection information
display_connection_info() {
    log_info "MongoDB Replica Set Installation Complete!"
    echo ""
    log_success "Your MongoDB replica set is now running!"
    echo ""
    echo "Connection Information:"
    echo "========================="
    echo ""
    echo "Admin User:"
    echo "  mongodb://cluster_admin:AdminSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/admin?replicaSet=rs0&authSource=admin"
    echo ""
    echo "Application Users:"
    echo "  # User One (db_one)"
    echo "  mongodb://user_one:UserOneSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/db_one?replicaSet=rs0&authSource=db_one"
    echo ""
    echo "  # User Two (db_two)"
    echo "  mongodb://user_two:UserTwoSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/db_two?replicaSet=rs0&authSource=db_two"
    echo ""
    echo "Documentation: docs/"
    echo "Scripts: scripts/"
    echo "Configuration: config/"
    echo ""
    echo "Useful Commands:"
    echo "  * Check container IPs: ./scripts/check-ips.sh"
    echo "  * Test cluster: docker run --rm --network mongo-cluster -v \$(pwd)/scripts:/scripts mongo:${MONGO_VERSION} bash /scripts/test-cluster.sh"
    echo "  * Stop cluster: docker compose down"
    echo "  * View logs: docker compose logs"
    echo ""
    log_warning "Remember: After restarting containers, you may need to update /etc/hosts again!"
}

# Main installation function
main() {
    echo "================================================"
    echo "MongoDB Replica Set Installation Script"
    echo "================================================"
    echo "Using MongoDB Version: ${MONGO_VERSION}"
    echo ""
    
    check_prerequisites
    cleanup_existing
    generate_keyfile
    create_external_volumes
    
    if start_cluster; then
        configure_network
        display_connection_info
        echo ""
        log_success "Installation completed successfully!"
        echo "================================================"
    else
        log_error "Installation failed. Please check the logs above."
        echo "================================================"
        exit 1
    fi
}

# Run main function
main "$@"

