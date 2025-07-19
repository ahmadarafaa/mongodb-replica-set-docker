# MongoDB Connection Reference

## Connection Strings

| User | Database | Connection String |
|------|----------|-------------------|
| **cluster_admin** | admin | `mongodb://cluster_admin:AdminSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/admin?replicaSet=rs0\u0026authSource=admin` |
| **user_one** | db_one | `mongodb://user_one:UserOneSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/db_one?replicaSet=rs0\u0026authSource=db_one` |
| **user_two** | db_two | `mongodb://user_two:UserTwoSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/db_two?replicaSet=rs0\u0026authSource=db_two` |

## Alternative Connection Methods

### Using localhost ports (requires /etc/hosts setup)
```
# Admin User
mongodb://cluster_admin:AdminSecurePass123%21@localhost:27017/admin

# User One (db_one)
mongodb://user_one:UserOneSecurePass123%21@localhost:27017/db_one

# User Two (db_two)  
mongodb://user_two:UserTwoSecurePass123%21@localhost:27018/db_two
```

### Direct IP connections (no /etc/hosts needed)
```
# First, get current IPs:
./scripts/check-ips.sh

# Then use the IPs directly (example IPs):
mongodb://cluster_admin:AdminSecurePass123%21@172.19.0.2:27017/admin
mongodb://user_one:UserOneSecurePass123%21@172.19.0.2:27017/db_one
mongodb://user_two:UserTwoSecurePass123%21@172.19.0.4:27017/db_two
```

## Connection Parameters Breakdown

| Parameter | Value | Purpose |
|-----------|-------|----------|
| **Protocol** | `mongodb://` | MongoDB connection protocol |
| **Username** | `cluster_admin`, `user_one`, `user_two` | Database user |
| **Password** | URL-encoded with `%21` for `!` | User password |
| **Hosts** | `mongo1:27017,mongo2:27017,mongo3:27017` | Replica set members |
| **Database** | `admin`, `db_one`, `db_two` | Target database |
| **replicaSet** | `rs0` | Replica set name |
| **authSource** | Database where user is defined | Authentication database |

## Important Notes

- **URL Encoding**: Special characters in passwords must be URL-encoded (`!` becomes `%21`)
- **Replica Set**: All connections specify `replicaSet=rs0` for proper failover
- **Host Resolution**: Container names (`mongo1`, `mongo2`, `mongo3`) require `/etc/hosts` entries
- **Port Mapping**: Containers map to `localhost:27017`, `localhost:27018`, `localhost:27019`
- **Authentication**: Each user is restricted to their designated database
- **Network**: Containers communicate on the `mongodb-task_mongo-cluster` Docker network

## Testing Connectivity

```bash
# Test from Docker network (bypasses /etc/hosts requirement)
docker run --rm --network mongodb-task_mongo-cluster -v $(pwd)/scripts:/scripts mongo:5.0 bash /scripts/test-cluster.sh
```
