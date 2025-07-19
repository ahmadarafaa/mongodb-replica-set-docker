# MongoDB Replica Set Task

A production-ready MongoDB 3-node replica set with authentication, containerized using Docker Compose. Optimized for development environments with resource constraints.

## ✨ Features

- **3-node replica set** with automatic failover
- **Authentication enabled** with dedicated users
- **Configurable MongoDB versions** via environment variables
- **Development-optimized** with resource limits and memory management
- **Persistent data storage** with Docker volumes
- **Network isolation** with custom Docker network
- **Automated setup** with installation script

## 📋 Prerequisites

- Docker
- Docker Compose
- Linux/Unix environment
- `mongosh` (recommended for testing)

## ⚙️ Configuration

The MongoDB version and other settings are configurable via the `.env` file:

```bash
# MongoDB Configuration
MONGO_VERSION=6.0

# Optional: Add other configurable parameters
MONGO_REPLICA_SET_NAME=rs0
```

### Supported MongoDB Versions
- **6.0** (default)
- **5.x** 
- **4.4** (may require compatibility adjustments)
- **7.0** (latest)

To change the MongoDB version:
1. Edit the `MONGO_VERSION` in `.env`
2. Run the installation: `./install.sh`

## 💻 Development Environment Optimizations

This MongoDB cluster is optimized for development environments with limited resources:

### 📊 Resource Limits (Per Container)
- **Memory**: 512MB limit, 256MB reserved
- **CPU**: 0.5 cores limit, 0.25 cores reserved
- **Total cluster**: ~1.5GB RAM, ~1.5 CPU cores

### ⚙️ MongoDB Optimizations
- **WiredTiger Cache**: 256MB per instance (reduced from default 50% of RAM)
- **Compression**: Snappy compression for better performance
- **Quiet Mode**: Reduced logging for cleaner output
- **Slow Query Threshold**: 1000ms for development debugging

### 🎥 Benefits
- **Low Resource Usage**: Suitable for laptops and development machines
- **Fast Startup**: Optimized configuration reduces initialization time
- **Development Friendly**: Balanced performance vs resource consumption
- **Production-Like**: Maintains replica set behavior and authentication

## 🚀 Quick Start

### Automated Installation
The installation script provides a fully automated setup with progress indicators:

```bash
./install.sh
```

**Installation Script Features:**
- ✨ Displays MongoDB version being used
- 🧡 Automatic cleanup of existing containers
- 🔐 Secure keyfile generation
- 📊 Progress indicators and health checks
- 📝 Clear connection information output

### Manual Installation
1. **Start the cluster:**
   ```bash
   docker compose up -d
   ```

2. **Check container IPs:**
   ```bash
   ./scripts/check-ips.sh
   ```

3. **Update `/etc/hosts`** (required for replica set hostname resolution):
   ```bash
   # Add the IP mappings from check-ips.sh to /etc/hosts
   # Example:
   # 172.19.0.2 mongo1
   # 172.19.0.4 mongo2
   # 172.19.0.3 mongo3
   ```

4. **Test the setup:**
   ```bash
   ./scripts/test-cluster.sh
   ```

## 🗂️ Project Structure

```
mongodb-task/
├── .env                       # Environment configuration (MongoDB version, etc.)
├── install.sh                 # Automated installation script
├── docker-compose.yml         # Docker Compose configuration
├── docker-compose.template.yml # Template without authentication
├── README.md                  # This documentation
├── config/
│   ├── init/                  # Database initialization scripts
│   │   └── setup-replica-set-working.sh
│   └── keyfile/               # Replica set authentication keyfile
│       └── mongo-keyfile
├── docs/
│   └── mongodb-connection-commands.md  # Detailed connection reference
└── scripts/
    ├── check-ips.sh           # Get container IP addresses
    └── test-cluster.sh        # Validate cluster health
```

## 🔗 Connection Information

After successful installation, use these connection strings with your MongoDB client:

### Admin User
```
mongodb://cluster_admin:AdminSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/admin?replicaSet=rs0&authSource=admin
```

### Application Users
```
# User One (db_one)
mongodb://user_one:UserOneSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/db_one?replicaSet=rs0&authSource=db_one

# User Two (db_two)
mongodb://user_two:UserTwoSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/db_two?replicaSet=rs0&authSource=db_two
```

### Using localhost ports (alternative)
```
# Admin User
mongodb://cluster_admin:AdminSecurePass123%21@localhost:27017/admin

# User One
mongodb://user_one:UserOneSecurePass123%21@localhost:27017/db_one

# User Two
mongodb://user_two:UserTwoSecurePass123%21@localhost:27018/db_two
```

## 🔧 Management Commands

```bash
# Start the cluster
docker compose up -d

# Stop the cluster
docker compose down

# Check container IPs
./scripts/check-ips.sh

# Test cluster health
./scripts/test-cluster.sh

# View logs
docker compose logs

# Clean removal (including volumes)
docker compose down -v

# Monitor resource usage
docker stats mongo1 mongo2 mongo3
```

## 📊 Resource Monitoring

```bash
# Check memory and CPU usage
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" mongo1 mongo2 mongo3

# Check MongoDB process info
docker exec mongo1 mongosh --eval "db.serverStatus().mem" --quiet

# Check WiredTiger cache usage
docker exec mongo1 mongosh --eval "db.serverStatus().wiredTiger.cache" --quiet
```

## 📋 Users & Access

| User | Database | Permissions | Purpose |
|------|----------|-------------|----------|
| `cluster_admin` | `admin` | Full admin access | Cluster administration |
| `user_one` | `db_one` | Read/Write to db_one | Application user 1 |
| `user_two` | `db_two` | Read/Write to db_two | Application user 2 |

## 🛠️ Troubleshooting

### Connection Issues
- **"Connection refused"**: Run `./scripts/check-ips.sh` and update `/etc/hosts` with current IPs
- **"ENOTFOUND mongo1"**: Container hostnames not in `/etc/hosts` - add IP mappings

### Authentication Issues
- **"Authentication failed"**: Wait for full initialization (up to 2 minutes)
- **"User not found"**: Ensure you're connecting to the correct database (authSource)

### Container Issues
- **"Containers not starting"**: Clean up and restart:
  ```bash
  docker compose down -v
  docker compose up -d
  ```

### Network Issues
- **After container restart**: IPs may change - rerun `./scripts/check-ips.sh` and update `/etc/hosts`

### Version Issues
- **Wrong MongoDB version**: Check `.env` file and ensure `MONGO_VERSION` is set correctly
- **Installation shows different version**: The install script displays the MongoDB version being used at startup
- **Version compatibility**: Some MongoDB versions may require different authentication mechanisms

### Testing from Docker Network
To test without `/etc/hosts` setup:
```bash
# Using default MongoDB version from .env
docker run --rm --network mongo-cluster -v $(pwd)/scripts:/scripts mongo:${MONGO_VERSION:-6.0} bash /scripts/test-cluster.sh

# Or specify version directly
docker run --rm --network mongo-cluster -v $(pwd)/scripts:/scripts mongo:6.0 bash /scripts/test-cluster.sh
```

## 🧹 Cleanup

```bash
# Stop and remove containers and volumes
docker compose down -v

# Remove /etc/hosts entries
sudo sed -i '/mongo1$/d' /etc/hosts
sudo sed -i '/mongo2$/d' /etc/hosts
sudo sed -i '/mongo3$/d' /etc/hosts
```

## 📚 Additional Documentation

- **Detailed Connection Reference**: `docs/mongodb-connection-commands.md`

---

**Note**: This setup is designed for development and testing. For production use, consider additional security hardening, monitoring, and backup strategies.
