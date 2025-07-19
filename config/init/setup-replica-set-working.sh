#!/bin/bash

# Wait for MongoDB instances to be ready
echo "Waiting for MongoDB instances to start..."
sleep 15

# Function to wait for MongoDB to be ready using localhost exception
wait_for_mongo() {
    local host=$1
    echo "Waiting for $host:27017 to be ready..."
    until mongosh --host $host:27017 --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1; do
        echo "$host:27017 is not ready yet, waiting..."
        sleep 3
    done
    echo "$host:27017 is ready!"
}

# Wait for primary MongoDB instance to be ready
wait_for_mongo mongo1

# Initialize replica set using localhost exception (auth is enabled but no users exist yet)
echo "Initializing replica set..."
mongosh --host mongo1:27017 --quiet --eval "
rs.initiate({
  _id: 'rs0',
  members: [
    { _id: 0, host: 'mongo1:27017', priority: 2 },
    { _id: 1, host: 'mongo2:27017', priority: 1 },
    { _id: 2, host: 'mongo3:27017', priority: 1 }
  ]
})
"

if [ $? -eq 0 ]; then
    echo "✅ Replica set initialized successfully"
else
    echo "❌ Failed to initialize replica set"
    exit 1
fi

# Wait for replica set to be ready
echo "Waiting for replica set to be ready..."
sleep 15

# Wait for primary election
echo "Waiting for primary election..."
count=0
while [ $count -lt 12 ]; do
    if mongosh --host mongo1:27017 --quiet --eval "rs.isMaster().ismaster" 2>/dev/null | grep -q "true"; then
        echo "✅ Primary elected successfully!"
        break
    fi
    echo "Waiting for primary election... (attempt $((count + 1)))"
    sleep 5
    count=$((count + 1))
done

# Create admin user (no auth required since we started without auth)
echo "Creating admin user..."
mongosh --host mongo1:27017 --quiet admin --eval "
try {
    db.createUser({
        user: 'cluster_admin',
        pwd: 'AdminSecurePass123!',
        roles: ['root']
    });
    print('✅ Admin user created successfully');
} catch (e) {
    print('❌ Failed to create admin user: ' + e.message);
    quit(1);
}
"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create admin user"
    exit 1
fi

# Wait for user creation to propagate
echo "Waiting for user creation to propagate..."
sleep 5

# Create application databases and users (no auth needed yet)
echo "Creating application databases and users..."
mongosh --host mongo1:27017 --quiet --eval "
try {
    // Create db_one and user_one
    db.getSiblingDB('db_one').createUser({
        user: 'user_one',
        pwd: 'UserOneSecurePass123!',
        roles: [{ role: 'readWrite', db: 'db_one' }]
    });
    print('✅ User one created successfully');
    
    // Create db_two and user_two
    db.getSiblingDB('db_two').createUser({
        user: 'user_two',
        pwd: 'UserTwoSecurePass123!',
        roles: [{ role: 'readWrite', db: 'db_two' }]
    });
    print('✅ User two created successfully');
} catch (e) {
    print('❌ Failed to create application users: ' + e.message);
    quit(1);
}
"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create application users"
    exit 1
fi

# Seed databases with test data (no auth needed yet)
echo "Seeding databases with test data..."
mongosh --host mongo1:27017 --quiet --eval "
try {
    // Seed db_one
    var db1Result = db.getSiblingDB('db_one').products.insertMany([
        { name: 'Laptop', category: 'Electronics', price: 999.99, inStock: true, created: new Date() },
        { name: 'Mouse', category: 'Electronics', price: 29.99, inStock: true, created: new Date() },
        { name: 'Keyboard', category: 'Electronics', price: 79.99, inStock: false, created: new Date() },
        { name: 'Monitor', category: 'Electronics', price: 299.99, inStock: true, created: new Date() },
        { name: 'Headphones', category: 'Electronics', price: 199.99, inStock: true, created: new Date() }
    ]);
    print('✅ Products data seeded: ' + db1Result.insertedIds.length + ' documents');
    
    var db1Orders = db.getSiblingDB('db_one').orders.insertMany([
        { orderId: 'ORD001', customerId: 'CUST001', total: 1099.98, status: 'completed', created: new Date() },
        { orderId: 'ORD002', customerId: 'CUST002', total: 299.99, status: 'pending', created: new Date() },
        { orderId: 'ORD003', customerId: 'CUST003', total: 509.97, status: 'shipped', created: new Date() },
        { orderId: 'ORD004', customerId: 'CUST001', total: 79.99, status: 'completed', created: new Date() },
        { orderId: 'ORD005', customerId: 'CUST004', total: 199.99, status: 'processing', created: new Date() }
    ]);
    print('✅ Orders data seeded: ' + db1Orders.insertedIds.length + ' documents');
    
    // Seed db_two
    var db2Employees = db.getSiblingDB('db_two').employees.insertMany([
        { empId: 'EMP001', name: 'John Doe', department: 'Engineering', salary: 75000, hired: new Date() },
        { empId: 'EMP002', name: 'Jane Smith', department: 'Marketing', salary: 65000, hired: new Date() },
        { empId: 'EMP003', name: 'Bob Johnson', department: 'Engineering', salary: 80000, hired: new Date() },
        { empId: 'EMP004', name: 'Alice Brown', department: 'HR', salary: 60000, hired: new Date() },
        { empId: 'EMP005', name: 'Charlie Wilson', department: 'Sales', salary: 70000, hired: new Date() }
    ]);
    print('✅ Employees data seeded: ' + db2Employees.insertedIds.length + ' documents');
    
    var db2Projects = db.getSiblingDB('db_two').projects.insertMany([
        { projId: 'PROJ001', name: 'Website Redesign', status: 'active', budget: 50000, created: new Date() },
        { projId: 'PROJ002', name: 'Mobile App', status: 'planning', budget: 100000, created: new Date() },
        { projId: 'PROJ003', name: 'Data Migration', status: 'completed', budget: 25000, created: new Date() },
        { projId: 'PROJ004', name: 'API Integration', status: 'active', budget: 75000, created: new Date() },
        { projId: 'PROJ005', name: 'Security Audit', status: 'pending', budget: 30000, created: new Date() }
    ]);
    print('✅ Projects data seeded: ' + db2Projects.insertedIds.length + ' documents');
    
} catch (e) {
    print('❌ Failed to seed data: ' + e.message);
    quit(1);
}
"

if [ $? -eq 0 ]; then
    echo "✅ Test data seeded successfully"
else
    echo "⚠️ Warning: Failed to seed test data, but cluster is functional"
fi

echo ""
echo "🎉 MongoDB replica set setup completed successfully!"
echo ""
echo "📋 Connection Details:"
echo "  Admin user: cluster_admin"
echo "  Password: AdminSecurePass123!"
echo "  Database: admin"
echo ""
echo "  App user 1: user_one"
echo "  Password: UserOneSecurePass123!"
echo "  Database: db_one"
echo ""
echo "  App user 2: user_two"
echo "  Password: UserTwoSecurePass123!"
echo "  Database: db_two"
echo ""
echo "🚀 Cluster is ready for use!"
