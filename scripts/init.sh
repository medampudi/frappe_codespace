#!/bin/bash

set -e

# Colors for better UX
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

# Function to get user input for app configuration
get_user_configuration() {
    print_header "🎯 FRAPPE APP CONFIGURATION"
    echo ""
    
    # Get app name
    while true; do
        echo -e "${BLUE}📱 Enter your Frappe app name:${NC}"
        echo -e "${YELLOW}   Rules: lowercase letters, numbers, underscores only${NC}"
        echo -e "${YELLOW}   Examples: my_app, sales_module, crm_system${NC}"
        read -p "App Name [my_frappe_app]: " user_app_name
        
        # Use default if empty
        user_app_name="${user_app_name:-my_frappe_app}"
        
        # Validate app name
        if validate_app_name "$user_app_name"; then
            APP_NAME="$user_app_name"
            break
        else
            print_error "Invalid app name. Please try again."
            echo ""
        fi
    done
    
    echo ""
    
    # Get GitHub repository preference
    echo -e "${BLUE}🏗️  Create GitHub repository automatically?${NC}"
    echo -e "${YELLOW}   This will create a private repo and push your code${NC}"
    read -p "Create GitHub repo? [Y/n]: " create_repo_input
    
    case "$create_repo_input" in
        [nN][oO]|[nN])
            CREATE_GITHUB_REPO="false"
            print_info "GitHub integration disabled"
            ;;
        *)
            CREATE_GITHUB_REPO="true"
            print_info "GitHub integration enabled"
            ;;
    esac
    
    echo ""
    
    # Get app installation preference
    echo -e "${BLUE}📦 Install app to development site automatically?${NC}"
    echo -e "${YELLOW}   This will install your app to dev.localhost${NC}"
    read -p "Auto-install app? [Y/n]: " install_app_input
    
    case "$install_app_input" in
        [nN][oO]|[nN])
            AUTO_INSTALL_APP="false"
            print_info "Manual app installation"
            ;;
        *)
            AUTO_INSTALL_APP="true"
            print_info "Automatic app installation"
            ;;
    esac
    
    echo ""
    print_header "📋 CONFIGURATION SUMMARY"
    echo -e "${CYAN}📱 App Name:${NC} $APP_NAME"
    echo -e "${CYAN}🏗️  GitHub Repo:${NC} $CREATE_GITHUB_REPO"
    echo -e "${CYAN}📦 Auto Install:${NC} $AUTO_INSTALL_APP"
    echo ""
    
    # Confirmation
    read -p "Proceed with this configuration? [Y/n]: " confirm
    case "$confirm" in
        [nN][oO]|[nN])
            print_info "Setup cancelled by user"
            exit 0
            ;;
        *)
            print_success "Configuration confirmed! Starting setup..."
            ;;
    esac
    
    echo ""
}

# Check if running in interactive mode or using environment variables
if [[ -t 0 && -z "$APP_NAME" && -z "$CODESPACE_NAME" ]]; then
    # Interactive mode - get user input
    get_user_configuration
else
    # Non-interactive mode - use environment variables or defaults
    APP_NAME="${APP_NAME:-${1:-my_frappe_app}}"
    CREATE_GITHUB_REPO="${CREATE_GITHUB_REPO:-true}"
    AUTO_INSTALL_APP="${AUTO_INSTALL_APP:-true}"
    
    print_header "🚀 AUTOMATED FRAPPE SETUP"
    print_info "App Name: $APP_NAME"
    print_info "GitHub Repo: $CREATE_GITHUB_REPO"
    print_info "Auto Install: $AUTO_INSTALL_APP"
    echo ""
fi

# Function to validate app name
validate_app_name() {
    local app_name="$1"
    
    if [[ ! "$app_name" =~ ^[a-z][a-z0-9_]*$ ]]; then
        echo "❌ Invalid app name: $app_name"
        echo "App name should:"
        echo "  - Start with a lowercase letter"
        echo "  - Contain only lowercase letters, numbers, and underscores"
        echo "  - Example: my_app, sales_module, crm_system"
        return 1
    fi
    
    return 0
}

# Function to install GitHub CLI
install_github_cli() {
    if command -v gh &> /dev/null; then
        echo "✅ GitHub CLI already installed"
        return 0
    fi
    
    echo "📦 Installing GitHub CLI..."
    
    # Install GitHub CLI
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq
    sudo apt install gh -y -qq
    
    echo "✅ GitHub CLI installed successfully"
}

# Function to check GitHub authentication
check_github_auth() {
    # Check if GITHUB_TOKEN is available (Codespaces automatically provides this)
    if [[ -n "$GITHUB_TOKEN" ]]; then
        echo "🔐 Using GitHub token from environment"
        echo "$GITHUB_TOKEN" | gh auth login --with-token
        
        # Verify authentication
        if gh auth status &> /dev/null; then
            echo "✅ GitHub CLI authenticated successfully"
            return 0
        fi
    fi
    
    # Check if already authenticated
    if gh auth status &> /dev/null; then
        echo "✅ GitHub CLI already authenticated"
        return 0
    fi
    
    echo "⚠️ GitHub authentication not available"
    echo "To enable GitHub integration after setup:"
    echo "  1. Run: gh auth login --scopes 'repo,workflow,write:packages'"
    echo "  2. Or set GITHUB_TOKEN environment variable"
    echo "  3. Then run: /workspace/scripts/create_frappe_app.sh $APP_NAME"
    return 1
}

# Function to get GitHub username
get_github_username() {
    if [[ -n "$GITHUB_USERNAME" ]]; then
        echo "$GITHUB_USERNAME"
        return 0
    fi
    
    # Try to get from GitHub API
    if gh auth status &> /dev/null; then
        local username
        username=$(gh api user --jq '.login' 2>/dev/null)
        if [[ -n "$username" ]]; then
            echo "$username"
            return 0
        fi
    fi
    
    # Try to get from git config
    local git_username
    git_username=$(git config --global user.name 2>/dev/null)
    if [[ -n "$git_username" ]]; then
        echo "$git_username"
        return 0
    fi
    
    # Default fallback
    echo "frappe-developer"
}

# Function to create GitHub repository
create_github_repo() {
    local repo_name="$1"
    local github_username="$2"
    
    echo "🏗️ Creating private GitHub repository: $repo_name"
    
    # Check if repo already exists
    if gh repo view "$github_username/$repo_name" &> /dev/null; then
        echo "📦 Repository $repo_name already exists"
        return 0
    fi
    
    # Create private repository
    if gh repo create "$repo_name" \
        --private \
        --description "Frappe application: $repo_name" \
        --gitignore Python \
        --license MIT; then
        echo "✅ Repository created: https://github.com/$github_username/$repo_name"
        return 0
    else
        echo "❌ Failed to create repository"
        return 1
    fi
}

# Function to setup app with GitHub integration
setup_app_with_github() {
    local app_name="$1"
    local github_username="$2"
    
    print_info "Setting up app: $app_name"
    
    # Navigate to bench directory
    cd /workspace/frappe-bench
    
    # Create the Frappe app if it doesn't exist
    if [[ ! -d "apps/$app_name" ]]; then
        print_info "Creating Frappe app: $app_name"
        bench new-app "$app_name"
        print_success "Frappe app created successfully"
    else
        print_info "App $app_name already exists"
    fi
    
    # Install app to site if requested
    if [[ "$AUTO_INSTALL_APP" == "true" ]]; then
        print_info "Installing app to dev.localhost..."
        if bench --site dev.localhost install-app "$app_name" 2>/dev/null; then
            print_success "App installed to development site"
        else
            print_warning "App might already be installed"
        fi
    else
        print_info "Skipping app installation (disabled by user)"
        echo -e "${YELLOW}💡 To install later:${NC} bench --site dev.localhost install-app $app_name"
    fi
    
    # Navigate to app directory
    cd "apps/$app_name"
    
    # Setup git configuration
    setup_git_config
    
    # Initialize local git repo first
    if [[ ! -d ".git" ]]; then
        print_info "Initializing local Git repository..."
        git init
        git add .
        git commit -m "Initial commit: Frappe app $app_name"
        git branch -M develop
        print_success "Local Git repository initialized"
    fi
    
    # Only proceed with GitHub if enabled and authentication is available
    if [[ "$CREATE_GITHUB_REPO" == "true" ]]; then
        if check_github_auth; then
            print_info "Setting up GitHub integration..."
            
            # Create GitHub repository
            if create_github_repo "$app_name" "$github_username"; then
                setup_git_repository "$app_name" "$github_username"
            else
                print_warning "GitHub repository creation failed, but app is ready for local development"
            fi
        else
            print_warning "GitHub authentication not available"
            print_info "App created locally with Git repository"
            echo -e "${YELLOW}💡 To setup GitHub later:${NC}"
            echo "  1. gh auth login --scopes 'repo,workflow,write:packages'"
            echo "  2. /workspace/scripts/create_frappe_app.sh $app_name"
        fi
    else
        print_info "GitHub integration disabled by user"
        print_success "App created locally with Git repository"
        echo -e "${YELLOW}📁 Local app path:${NC} /workspace/frappe-bench/apps/$app_name"
    fi
}

# Function to setup git repository
setup_git_repository() {
    local app_name="$1"
    local github_username="$2"
    
    # Initialize git repository if not already initialized
    if [[ ! -d ".git" ]]; then
        echo "🎯 Initializing Git repository..."
        git init
        git add .
        git commit -m "Initial commit: Frappe app $app_name"
    fi
    
    # Create and switch to develop branch
    echo "🌿 Setting up develop branch..."
    git checkout -b develop 2>/dev/null || git checkout develop
    
    # Add remote origin
    echo "🔗 Adding remote origin..."
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://github.com/$github_username/$app_name.git"
    
    # Push to GitHub
    echo "📤 Pushing to GitHub..."
    if git push -u origin develop; then
        # Set develop as default branch
        echo "🌿 Setting develop as default branch..."
        gh repo edit "$github_username/$app_name" --default-branch develop 2>/dev/null || echo "⚠️ Could not set default branch (check permissions)"
        
        echo "✅ GitHub integration completed!"
        echo "🔗 Repository URL: https://github.com/$github_username/$app_name"
    else
        echo "❌ Failed to push to GitHub"
        echo "💡 You can manually push later with: git push -u origin develop"
    fi
}

# Function to setup git configuration
setup_git_config() {
    echo "⚙️ Setting up Git configuration..."
    
    # Get GitHub username if authenticated
    local github_user
    github_user=$(get_github_username)
    
    # Set up git config if not already set
    if [ -z "$(git config --global user.name)" ]; then
        git config --global user.name "$github_user"
        echo "✅ Git user.name set to: $github_user"
    fi
    
    if [ -z "$(git config --global user.email)" ]; then
        # Try to get email from GitHub API
        local github_email=""
        if gh auth status &> /dev/null; then
            github_email=$(gh api user --jq '.email' 2>/dev/null)
            if [[ "$github_email" == "null" || -z "$github_email" ]]; then
                github_email="$github_user@users.noreply.github.com"
            fi
        else
            github_email="$github_user@users.noreply.github.com"
        fi
        
        git config --global user.email "$github_email"
        echo "✅ Git user.email set to: $github_email"
    fi
    
    # Configure Git to use token authentication
    git config --global credential.helper store
    git config --global init.defaultBranch main
    
    echo "✅ Git configuration completed"
}
# Validate app name first
if ! validate_app_name "$APP_NAME"; then
    print_error "Invalid app name: $APP_NAME"
    exit 1
fi

print_header "🔧 SYSTEM SETUP"

# Install GitHub CLI early
install_github_cli

# Setup git configuration early
setup_git_config

# Get GitHub username
GITHUB_USERNAME=$(get_github_username)
print_info "GitHub Username: $GITHUB_USERNAME"

# Check if bench already exists
if [[ -d "/workspace/frappe-bench/apps/frappe" ]]; then
    print_info "Existing Frappe bench detected"
    
    # Setup the app (create if needed, setup GitHub integration)
    setup_app_with_github "$APP_NAME" "$GITHUB_USERNAME"
else
    print_header "🏗️ FRAPPE BENCH INITIALIZATION"
    # Initial Frappe bench setup
    print_info "Setting up initial Frappe bench..."
    
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

    print_success "Frappe bench setup completed!"
    
    print_header "📱 CUSTOM APP SETUP"
    # Now setup the custom app with GitHub integration
    setup_app_with_github "$APP_NAME" "$GITHUB_USERNAME"
fi

print_header "🎉 SETUP COMPLETE"
print_success "Frappe development environment ready!"
echo ""
echo -e "${CYAN}📱 App:${NC} $APP_NAME"
echo -e "${CYAN}🌐 Site:${NC} dev.localhost"
echo -e "${CYAN}👤 Username:${NC} Administrator"
echo -e "${CYAN}🔑 Password:${NC} admin"
echo ""
echo -e "${YELLOW}🚀 To start development:${NC}"
echo "  cd /workspace/frappe-bench"
echo "  bench start"
echo ""
echo -e "${YELLOW}📂 Your app directory:${NC}"
echo "  /workspace/frappe-bench/apps/$APP_NAME"

# Display GitHub integration status
if [[ "$CREATE_GITHUB_REPO" == "true" ]] && gh auth status &> /dev/null; then
    echo ""
    print_success "GitHub integration: Active"
    echo -e "${CYAN}🔗 Repository:${NC} https://github.com/$GITHUB_USERNAME/$APP_NAME"
    echo -e "${CYAN}🌿 Default branch:${NC} develop"
elif [[ "$CREATE_GITHUB_REPO" == "true" ]]; then
    echo ""
    print_warning "GitHub integration: Not configured"
    echo -e "${YELLOW}💡 To setup later:${NC}"
    echo "  gh auth login --scopes 'repo,workflow,write:packages'"
    echo "  /workspace/scripts/create_frappe_app.sh $APP_NAME"
else
    echo ""
    print_info "GitHub integration: Disabled by user"
fi

echo ""
print_success "Happy coding! 🎉"
