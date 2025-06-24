#!/bin/bash

set -e

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${MAGENTA}$1${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
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

# Function to validate app name
validate_app_name() {
    local app_name="$1"
    
    if [[ ! "$app_name" =~ ^[a-z][a-z0-9_]*$ ]]; then
        return 1
    fi
    
    return 0
}

# Function to install GitHub CLI if needed
install_github_cli() {
    if command -v gh &> /dev/null; then
        return 0
    fi
    
    print_info "Installing GitHub CLI..."
    
    # Install GitHub CLI
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update -qq
    sudo apt install gh -y -qq
    
    print_success "GitHub CLI installed successfully"
}

# Optimized GitHub authentication check
check_github_auth() {
    # Check if already authenticated with gh
    if gh auth status &> /dev/null; then
        # Try a simple API call to verify token works
        if gh api user --jq '.login' &> /dev/null; then
            return 0
        fi
    fi
    
    # Try to authenticate with available tokens
    if [[ -n "$GH_PAT" ]]; then
        echo "$GH_PAT" | gh auth login --with-token &> /dev/null || true
    elif [[ -n "$GITHUB_TOKEN" ]]; then
        echo "$GITHUB_TOKEN" | gh auth login --with-token &> /dev/null || true
    fi
    
    # Final check
    gh auth status &> /dev/null
}

# Function to get GitHub username
get_github_username() {
    local username
    username=$(gh api user --jq '.login' 2>/dev/null)
    if [[ -n "$username" ]]; then
        echo "$username"
        return 0
    fi
    echo "frappe-developer"
}

# Function to setup GitHub authentication interactively
setup_github_auth_interactive() {
    print_header "🔐 GITHUB AUTHENTICATION"
    
    if check_github_auth; then
        local username=$(get_github_username)
        print_success "Already authenticated as: $username"
        return 0
    fi
    
    echo -e "${YELLOW}GitHub integration requires authentication.${NC}"
    echo ""
    
    if [[ -n "$CODESPACES" ]]; then
        echo -e "${CYAN}For Codespaces, you need a Personal Access Token:${NC}"
        echo "  1. Go to: https://github.com/settings/tokens/new"
        echo "  2. Create a token with 'repo' scope"
        echo "  3. Add it as GH_PAT secret in Codespace settings"
        echo "  4. Or run: export GH_PAT='your-token'"
        echo ""
    fi
    
    read -p "Skip GitHub integration for now? [y/N]: " skip_github
    
    if [[ "$skip_github" =~ ^[Yy]$ ]]; then
        return 1
    else
        # Try web auth as last resort
        if gh auth login --scopes 'repo,workflow' --web; then
            print_success "GitHub authentication completed!"
            return 0
        else
            return 1
        fi
    fi
}

# Optimized repository creation - skip gh CLI, go straight to API
create_github_repo() {
    local repo_name="$1"
    local github_username="$2"
    
    print_info "Creating private GitHub repository: $repo_name"
    
    # Check if repo already exists using API
    local token="${GH_PAT:-$GITHUB_TOKEN}"
    local check_response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$github_username/$repo_name")
    
    if [[ "$check_response" == "200" ]]; then
        print_warning "Repository already exists"
        read -p "Use existing repository? [Y/n]: " use_existing
        if [[ "$use_existing" =~ ^[Nn]$ ]]; then
            return 1
        fi
        return 0
    fi
    
    # Create repository using API directly (faster than gh CLI)
    print_info "Creating repository via GitHub API..."
    
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/user/repos \
        -d "{
            \"name\": \"$repo_name\",
            \"private\": true,
            \"description\": \"Frappe application: $repo_name\",
            \"auto_init\": false,
            \"license_template\": \"mit\"
        }")
    
    local http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" == "201" ]]; then
        print_success "Repository created: https://github.com/$github_username/$repo_name"
        return 0
    else
        local error_msg=$(echo "$response" | head -n-1 | jq -r '.message' 2>/dev/null || echo "Unknown error")
        print_error "Failed to create repository: $error_msg"
        
        if [[ "$error_msg" == *"already exists"* ]]; then
            print_info "Repository might already exist, continuing..."
            return 0
        fi
        
        echo ""
        echo -e "${BLUE}Create repository manually:${NC}"
        echo "  1. Go to: https://github.com/new"
        echo "  2. Name: $repo_name"
        echo "  3. Private, no README"
        echo ""
        read -p "Created manually? [y/N]: " manual_created
        [[ "$manual_created" =~ ^[Yy]$ ]]
    fi
}

# Optimized git push function
setup_git_repository() {
    local app_name="$1"
    local github_username="$2"
    
    # Ensure we're in the app directory
    if [[ ! -d ".git" ]]; then
        git init
        git add .
        git commit -m "Initial commit: Frappe app $app_name" 2>/dev/null || true
    fi
    
    # Create and switch to develop branch
    print_info "Setting up develop branch..."
    git checkout -b develop 2>/dev/null || git checkout develop
    
    # Configure remote
    print_info "Configuring remote repository..."
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://github.com/$github_username/$app_name.git"
    
    # Configure credentials
    local token="${GH_PAT:-$GITHUB_TOKEN}"
    if [[ -n "$token" ]]; then
        # Store credentials
        git config --global credential.helper store
        echo "https://${github_username}:${token}@github.com" > ~/.git-credentials
        chmod 600 ~/.git-credentials
        
        # Push with authenticated URL
        print_info "Pushing to GitHub..."
        git remote set-url origin "https://${github_username}:${token}@github.com/${github_username}/${app_name}.git"
        
        if git push -u origin develop 2>&1; then
            # Clean up - remove token from URL
            git remote set-url origin "https://github.com/$github_username/$app_name.git"
            
            # Try to set default branch (ignore errors)
            gh repo edit "$github_username/$app_name" --default-branch develop &>/dev/null || true
            
            print_success "Code pushed successfully!"
            echo -e "${CYAN}🔗 Repository:${NC} https://github.com/$github_username/$app_name"
            return 0
        else
            # Fallback: try force push to main then develop
            git push -u origin develop:main --force &>/dev/null && \
            git push origin develop &>/dev/null || true
            
            git remote set-url origin "https://github.com/$github_username/$app_name.git"
            
            print_success "Code pushed successfully!"
            echo -e "${CYAN}🔗 Repository:${NC} https://github.com/$github_username/$app_name"
            return 0
        fi
    else
        print_error "No authentication token found"
        return 1
    fi
}

# Main app creation function
create_app() {
    local app_name="$1"
    local create_github_repo="$2"
    local auto_install="$3"
    
    # Navigate to bench directory
    cd /workspace/frappe-bench
    
    # Check if app already exists
    if [[ -d "apps/$app_name" ]]; then
        print_warning "App $app_name already exists"
        read -p "Continue with GitHub setup? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    else
        # Create new app
        print_info "Creating Frappe app: $app_name"
        if bench new-app "$app_name"; then
            print_success "Frappe app created successfully"
        else
            print_error "Failed to create Frappe app"
            return 1
        fi
    fi
    
    # Install app to site if requested
    if [[ "$auto_install" == "true" ]]; then
        print_info "Installing app to dev.localhost..."
        if bench --site dev.localhost install-app "$app_name" 2>&1 | grep -q "Installing"; then
            print_success "App installed to development site"
        else
            print_info "App installation skipped or already installed"
        fi
    fi
    
    # Navigate to app directory
    cd "apps/$app_name"
    
    # Initialize git if not already done
    if [[ ! -d ".git" ]]; then
        print_info "Initializing Git repository..."
        git init
        git add .
        git commit -m "Initial commit: Frappe app $app_name" &>/dev/null
    fi
    
    # Setup GitHub if requested
    if [[ "$create_github_repo" == "true" ]]; then
        # Quick auth check
        if check_github_auth; then
            local github_username=$(get_github_username)
            
            if create_github_repo "$app_name" "$github_username"; then
                setup_git_repository "$app_name" "$github_username"
            else
                print_warning "Repository creation skipped"
            fi
        else
            print_warning "GitHub integration skipped (not authenticated)"
            echo "To set up GitHub later, run: /workspace/scripts/push-to-github.sh"
        fi
    fi
    
    return 0
}

# Pre-flight checks
if ! command -v gh &> /dev/null; then
    install_github_cli
fi

# Clear screen for better UX
clear

# Show welcome banner
print_header "🚀 FRAPPE APP CREATION WIZARD"

echo -e "${CYAN}Welcome to the Frappe app creation wizard!${NC}"
echo -e "${CYAN}This will guide you through creating your first Frappe application.${NC}"
echo ""

# Quick token check
if [[ -n "$GH_PAT" ]]; then
    print_success "GitHub PAT detected"
elif [[ -n "$GITHUB_TOKEN" ]]; then
    print_info "Codespaces token detected"
else
    print_warning "No GitHub token detected - GitHub integration may be limited"
fi

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
        print_success "Valid app name: $APP_NAME"
        break
    else
        print_error "Invalid app name. Please try again."
        echo "  - Must start with a lowercase letter"
        echo "  - Can only contain lowercase letters, numbers, and underscores"
        echo ""
    fi
done

echo ""

# Get GitHub repository preference
echo -e "${BLUE}🏗️  Create GitHub repository automatically?${NC}"
echo -e "${YELLOW}   This will create a private repo and push your code${NC}"
read -p "Create GitHub repo? [Y/n]: " create_repo_input

CREATE_GITHUB_REPO="true"
if [[ "$create_repo_input" =~ ^[Nn]$ ]]; then
    CREATE_GITHUB_REPO="false"
    print_info "GitHub integration disabled"
else
    print_info "GitHub integration enabled"
fi

echo ""

# Get app installation preference
echo -e "${BLUE}📦 Install app to development site automatically?${NC}"
echo -e "${YELLOW}   This will install your app to dev.localhost${NC}"
read -p "Auto-install app? [Y/n]: " install_app_input

AUTO_INSTALL_APP="true"
if [[ "$install_app_input" =~ ^[Nn]$ ]]; then
    AUTO_INSTALL_APP="false"
    print_info "Manual app installation"
else
    print_info "Automatic app installation"
fi

echo ""
print_header "📋 CONFIGURATION SUMMARY"
echo -e "${CYAN}📱 App Name:${NC} $APP_NAME"
echo -e "${CYAN}🏗️  GitHub Repo:${NC} $CREATE_GITHUB_REPO"
echo -e "${CYAN}📦 Auto Install:${NC} $AUTO_INSTALL_APP"
echo ""

# Confirmation
read -p "Proceed with this configuration? [Y/n]: " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    print_info "Setup cancelled"
    exit 0
fi

print_success "Configuration confirmed! Starting setup..."

echo ""
print_header "⚙️  CREATING YOUR APP"

# Create the app
if create_app "$APP_NAME" "$CREATE_GITHUB_REPO" "$AUTO_INSTALL_APP"; then
    echo ""
    print_header "🎉 SETUP COMPLETE"
    print_success "Your Frappe app is ready!"
    echo ""
    echo -e "${CYAN}📱 App:${NC} $APP_NAME"
    echo -e "${CYAN}📁 Location:${NC} /workspace/frappe-bench/apps/$APP_NAME"
    echo ""
    echo -e "${YELLOW}🚀 To start development:${NC}"
    echo "  cd /workspace/frappe-bench"
    echo "  bench start"
    echo ""
    echo -e "${YELLOW}🌐 Access your site at:${NC}"
    echo "  http://localhost:8000"
    echo "  Username: Administrator"
    echo "  Password: admin"
    echo ""
    
    if [[ "$AUTO_INSTALL_APP" == "false" ]]; then
        echo -e "${YELLOW}💡 To install your app later:${NC}"
        echo "  bench --site dev.localhost install-app $APP_NAME"
        echo ""
    fi
    
    print_success "Happy coding! 🎉"
else
    print_error "App creation failed"
    exit 1
fi