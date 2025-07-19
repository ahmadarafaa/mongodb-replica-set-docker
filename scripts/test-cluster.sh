#!/bin/bash

# Test replica set status first
if mongosh 'mongodb://cluster_admin:AdminSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/admin?replicaSet=rs0&authSource=admin' --eval "rs.status().members.length" --quiet &>/dev/null; then
    echo "✅ replica_set: Healthy"
else
    echo "❌ replica_set: Unhealthy"
    echo "❌ Cannot proceed with user tests - replica set is not accessible"
    exit 1
fi

# Test cluster_admin user
if mongosh 'mongodb://cluster_admin:AdminSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/admin?replicaSet=rs0&authSource=admin' --eval "rs.status().ok" --quiet &>/dev/null; then
    echo "✅ cluster_admin: Connected"
else
    echo "❌ cluster_admin: Failed"
fi

# Test user_one
if mongosh 'mongodb://user_one:UserOneSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/db_one?replicaSet=rs0&authSource=db_one' --eval "db.products.countDocuments()" --quiet &>/dev/null; then
    echo "✅ user_one: Connected"
else
    echo "❌ user_one: Failed"
fi

# Test user_two
if mongosh 'mongodb://user_two:UserTwoSecurePass123%21@mongo1:27017,mongo2:27017,mongo3:27017/db_two?replicaSet=rs0&authSource=db_two' --eval "db.employees.countDocuments()" --quiet &>/dev/null; then
    echo "✅ user_two: Connected"
else
    echo "❌ user_two: Failed"
fi
