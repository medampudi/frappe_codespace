# scripts/init.sh - Fixed version
#!/bin/bash

set -e

if [[ -f "/workspace/frappe-bench/apps/frappe" ]]
then
    echo "Bench already exists, skipping init"
    exit 0
fi

rm -rf /workspace/frappe_codespace/.git

# Fix Node.js setup
source /home/frappe/.nvm/nvm.sh
nvm install 18
nvm alias default 18
nvm use 18

echo "source /home/frappe/.nvm/nvm.sh" >> ~/.bashrc
echo "nvm use 18" >> ~/.bashrc

cd /workspace

bench init \
--ignore-exist \
--skip-redis-config-generation \
frappe-bench

cd frappe-bench

# Use containers instead of localhost
bench set-mariadb-host mariadb
bench set-config -g redis_cache "redis://redis-cache:6379"
bench set-config -g redis_queue "redis://redis-queue:6379"
bench set-config -g redis_socketio "redis://redis-socketio:6379"

# Remove redis from Procfile
sed -i '/redis/d' ./Procfile

bench new-site dev.localhost \
--mariadb-root-password 123 \
--admin-password admin \
--db-root-username root \
--mariadb-user-host-login-scope='%'

bench --site dev.localhost set-config developer_mode 1
bench --site dev.localhost clear-cache
bench use dev.localhost
