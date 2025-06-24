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
    # Set default git config if not already set
    if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
        git config --global user.name "Frappe Developer"
    fi
    
    if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
        git config --global user.email "developer@frappe.local"
    fi
    
    # Configure Git defaults
    git config --global credential.helper store
    git config --global init.defaultBranch main
    git config --global pull.rebase false
}

print_header "🏗️ FRAPPE BENCH INITIALIZATION"

# Make all scripts executable first
print_info "Setting script permissions..."
chmod +x /workspace/scripts/*.sh 2>/dev/null || true

# Check if bench already exists
if [[ -d "/workspace/frappe-bench/apps/frappe" ]]; then
    print_success "Frappe bench already initialized"
    print_info "Run 'create-app' command in terminal to create your Frappe app"
    
    # Ensure terminal setup is done
    if [ ! -f ~/.first_terminal_shown ]; then
        /workspace/scripts/setup-terminal.sh &>/dev/null || true
    fi
    
    exit 0
fi

# Clean up git if exists
if [[ -d "/workspace/.git" ]]; then
    rm -rf /workspace/.git
fi

# Quick Node.js setup
print_info "Setting up Node.js environment..."

# Check if nvm is already installed
if [[ ! -d "$HOME/.nvm" ]]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash &>/dev/null
fi

# Source nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node 18 if not already installed
if ! nvm list 18 &>/dev/null; then
    print_info "Installing Node.js 18..."
    nvm install 18 &>/dev/null
fi

nvm use 18 &>/dev/null
nvm alias default 18 &>/dev/null

# Install yarn if needed
if ! command -v yarn &>/dev/null; then
    npm install -g yarn &>/dev/null
fi

# Add to bashrc if not already there
if ! grep -q "NVM_DIR" ~/.bashrc; then
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
    echo 'nvm use 18 &>/dev/null' >> ~/.bashrc
fi

# Quick version check
print_success "Development environment ready"

# Setup git configuration
setup_git_config

print_info "Initializing Frappe bench..."
cd /workspace

# Initialize bench with minimal output
bench init \
    --ignore-exist \
    --skip-redis-config-generation \
    --python python3 \
    --no-backups \
    --no-auto-update \
    frappe-bench 2>&1 | grep -E "(Installing|Creating|Initializing)" || true

cd frappe-bench

# Configure services
print_info "Configuring services..."
bench set-mariadb-host mariadb &>/dev/null
bench set-config -g redis_cache "redis://redis-cache:6379" &>/dev/null
bench set-config -g redis_queue "redis://redis-queue:6379" &>/dev/null
bench set-config -g redis_socketio "redis://redis-socketio:6379" &>/dev/null

# Remove redis from Procfile
sed -i '/redis/d' ./Procfile 2>/dev/null || true

# Wait for MariaDB
print_info "Waiting for database..."
timeout=30
while ! mysqladmin ping -h mariadb -u root -p123 --silent 2>/dev/null; do
    timeout=$((timeout - 1))
    if [ $timeout -eq 0 ]; then
        print_error "MariaDB connection timeout"
        exit 1
    fi
    sleep 1
done

print_info "Creating development site..."
bench new-site dev.localhost \
    --mariadb-root-password 123 \
    --admin-password admin \
    --db-root-username root \
    --mariadb-user-host-login-scope='%' 2>&1 | grep -E "(Creating|Installing)" || true

# Quick configuration
bench --site dev.localhost set-config developer_mode 1 &>/dev/null
bench --site dev.localhost clear-cache &>/dev/null
bench use dev.localhost &>/dev/null

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
  bench start (or use alias: bs)

Happy coding! 🚀
EOF

# Create a flag file to indicate setup is complete
touch /workspace/.bench_setup_complete

print_success "Frappe bench setup completed!"

# Setup terminal environment
print_info "Configuring terminal environment..."
if /workspace/scripts/setup-terminal.sh; then
    print_success "Terminal environment configured"
else
    print_warning "Terminal setup had issues but continuing..."
fi

print_success "Setup complete! Terminal will open soon with app creation wizard..."

# Exit successfully
exit 0