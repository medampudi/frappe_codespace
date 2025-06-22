#!/bin/bash

set -e

echo "Starting Frappe Bench initialization..."

# Check if bench already exists
if [[ -d "/workspace/frappe-bench/apps/frappe" ]]; then
    echo "Bench already exists, skipping init"
    exit 0
fi

# Clean up git if exists
if [[ -d "/workspace/.git" ]]; then
    rm -rf /workspace/.git
fi

echo "Setting up Node.js..."

# Install nvm if not exists
if [[ ! -d "$HOME/.nvm" ]]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Source nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Install and use Node 18
echo "Installing Node.js 18..."
nvm install 18
nvm use 18
nvm alias default 18

# Install yarn globally
echo "Installing yarn..."
npm install -g yarn

# Add to bashrc
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc
echo "nvm use 18" >> ~/.bashrc

# Verify installations
echo "Node version: $(node --version)"
echo "NPM version: $(npm --version)"
echo "Yarn version: $(yarn --version)"
echo "Python version: $(python3 --version)"

echo "Navigating to workspace..."
cd /workspace

echo "Initializing Frappe bench..."
bench init \
--ignore-exist \
--skip-redis-config-generation \
--python python3 \
frappe-bench

cd frappe-bench

echo "Configuring external services..."
# Use containers instead of localhost
bench set-mariadb-host mariadb
bench set-config -g redis_cache "redis://redis-cache:6379"
bench set-config -g redis_queue "redis://redis-queue:6379"
bench set-config -g redis_socketio "redis://redis-socketio:6379"

# Remove redis from Procfile
sed -i '/redis/d' ./Procfile

echo "Creating new site..."
# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
while ! mysqladmin ping -h mariadb -u root -p123 --silent; do
    echo "Waiting for MariaDB..."
    sleep 2
done

bench new-site dev.localhost \
--mariadb-root-password 123 \
--admin-password admin \
--db-root-username root \
--mariadb-user-host-login-scope='%'

echo "Configuring development environment..."
bench --site dev.localhost set-config developer_mode 1
bench --site dev.localhost clear-cache
bench use dev.localhost

echo "✅ Frappe bench initialization completed successfully!"
echo "🌐 Site: dev.localhost"
echo "👤 Username: Administrator"
echo "🔑 Password: admin"
echo ""
echo "To start the development server:"
echo "  cd frappe-bench"
echo "  bench start"
