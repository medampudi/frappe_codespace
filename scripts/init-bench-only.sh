#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to setup git configuration
setup_git_config() {
    echo "⚙️ Setting up Git configuration..."
    
    # Set default git config if not already set
    if [ -z "$(git config --global user.name)" ]; then
        git config --global user.name "Frappe Developer"
        echo "✅ Git user.name set to: Frappe Developer"
    fi
    
    if [ -z "$(git config --global user.email)" ]; then
        git config --global user.email "developer@frappe.local"
        echo "✅ Git user.email set to: developer@frappe.local"
    fi
    
    # Configure Git defaults
    git config --global credential.helper store
    git config --global init.defaultBranch main
    
    echo "✅ Git configuration completed"
}

print_header "🏗️ FRAPPE BENCH INITIALIZATION"

# Check if bench already exists
if [[ -d "/workspace/frappe-bench/apps/frappe" ]]; then
    print_success "Frappe bench already initialized"
    print_info "Run 'create-app' command in terminal to create your Frappe app"
    exit 0
fi

# Clean up git if exists
if [[ -d "/workspace/.git" ]]; then
    rm -rf /workspace/.git
fi

print_info "Installing Node.js..."

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
print_info "Installing Node.js 18..."
nvm install 18
nvm use 18
nvm alias default 18

# Install yarn globally
print_info "Installing yarn..."
npm install -g yarn

# Add to bashrc
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc
echo "nvm use 18" >> ~/.bashrc

# Verify installations
print_success "Node version: $(node --version)"
print_success "NPM version: $(npm --version)"
print_success "Yarn version: $(yarn --version)"
print_success "Python version: $(python3 --version)"

# Setup git configuration
setup_git_config

print_info "Navigating to workspace..."
cd /workspace

print_info "Initializing Frappe bench..."
bench init \
    --ignore-exist \
    --skip-redis-config-generation \
    --python python3 \
    frappe-bench

cd frappe-bench

print_info "Configuring external services..."
# Use containers instead of localhost
bench set-mariadb-host mariadb
bench set-config -g redis_cache "redis://redis-cache:6379"
bench set-config -g redis_queue "redis://redis-queue:6379"
bench set-config -g redis_socketio "redis://redis-socketio:6379"

# Remove redis from Procfile
sed -i '/redis/d' ./Procfile

print_info "Creating development site..."
# Wait for MariaDB to be ready
print_info "Waiting for MariaDB to be ready..."
while ! mysqladmin ping -h mariadb -u root -p123 --silent; do
    echo "Waiting for MariaDB..."
    sleep 2
done

bench new-site dev.localhost \
    --mariadb-root-password 123 \
    --admin-password admin \
    --db-root-username root \
    --mariadb-user-host-login-scope='%'

print_info "Configuring development environment..."
bench --site dev.localhost set-config developer_mode 1
bench --site dev.localhost clear-cache
bench use dev.localhost

# Create welcome message file
cat > /workspace/.welcome_message <<'EOF'

🎉 FRAPPE DEVELOPMENT ENVIRONMENT READY!

Your Frappe bench is initialized with:
  🌐 Site: dev.localhost
  👤 Username: Administrator
  🔑 Password: admin

To create your first Frappe app, run:
  create-app

To start the development server:
  cd /workspace/frappe-bench && bench start

Happy coding! 🚀
EOF

# Create a flag file to indicate setup is complete
touch /workspace/.bench_setup_complete

print_success "Frappe bench setup completed!"

# Setup terminal environment
print_info "Configuring terminal environment..."
/workspace/scripts/setup-terminal.sh

print_info "Terminal will open soon with app creation wizard..."