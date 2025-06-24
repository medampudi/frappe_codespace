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

# Function to check GitHub authentication
check_github_auth() {
    # Check if GITHUB_TOKEN is available (Codespaces automatically provides this)
    if [[ -n "$GITHUB_TOKEN" ]]; then
        echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null
    fi
    
    # Check if authenticated
    if gh auth status &> /dev/null; then
        return 0
    fi
    
    return 1
}

# Function to get GitHub username
get_github_username() {
    if gh auth status &> /dev/null; then
        local username
        username=$(gh api user --jq '.login' 2>/dev/null)
        if [[ -n "$username" ]]; then
            echo "$username"
            return 0
        fi
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
    echo -e "${CYAN}This will allow automatic repository creation and code push.${NC}"
    echo ""
    read -p "Would you like to authenticate with GitHub now? [Y/n]: " auth_choice
    
    case "$auth_choice" in
        [nN][oO]|[nN])
            print_info "Skipping GitHub authentication"
            return 1
            ;;
        *)
            print_info "Opening browser for GitHub authentication..."
            echo -e "${YELLOW}Please complete the authentication in your browser${NC}"
            
            if gh auth login --scopes 'repo,workflow,write:packages' --web; then
                print_success "GitHub authentication completed!"
                return 0
            else
                print_error "GitHub authentication failed"
                return 1
            fi
            ;;
    esac
}

# Function to create GitHub repository
create_github_repo() {
    local repo_name="$1"
    local github_username="$2"
    
    print_info "Creating private GitHub repository: $repo_name"
    
    # Check if repo already exists
    if gh repo view "$github_username/$repo_name" &> /dev/null; then
        print_warning "Repository $repo_name already exists"
        return 0
    fi
    
    # Create private repository
    if gh repo create "$repo_name" \
        --private \
        --description "Frappe application: $repo_name" \
        --gitignore Python \
        --license MIT 2>/tmp/gh_error.log; then
        print_success "Repository created: https://github.com/$github_username/$repo_name"
        return 0
    else
        print_error "Failed to create repository"
        
        # Check if it's a permissions issue
        if grep -q "403" /tmp/gh_error.log 2>/dev/null || grep -q "Resource not accessible" /tmp/gh_error.log 2>/dev/null; then
            echo ""
            print_warning "GitHub permissions issue detected!"
            echo -e "${YELLOW}The GitHub token doesn't have sufficient permissions to create repositories.${NC}"
            echo ""
            echo -e "${CYAN}To fix this, you have two options:${NC}"
            echo ""
            echo -e "${BLUE}Option 1: Grant permissions to Codespace${NC}"
            echo "  1. Go to: https://github.com/settings/codespaces"
            echo "  2. Find this Codespace and click 'Manage'"
            echo "  3. Under 'Repository permissions', grant 'write' access"
            echo "  4. Restart the Codespace"
            echo ""
            echo -e "${BLUE}Option 2: Create repository manually${NC}"
            echo "  You can create the repository manually and push your code:"
            echo ""
            echo "  # Create repo on GitHub.com, then run:"
            echo "  cd /workspace/frappe-bench/apps/$repo_name"
            echo "  git remote add origin https://github.com/$github_username/$repo_name.git"
            echo "  git push -u origin develop"
            echo ""
        fi
        
        return 1
    fi
}

# Function to setup git repository
setup_git_repository() {
    local app_name="$1"
    local github_username="$2"
    
    # Create and switch to develop branch
    print_info "Setting up develop branch..."
    git checkout -b develop 2>/dev/null || git checkout develop
    
    # Add remote origin
    print_info "Adding remote origin..."
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://github.com/$github_username/$app_name.git"
    
    # Push to GitHub
    print_info "Pushing to GitHub..."
    if git push -u origin develop; then
        # Set develop as default branch
        gh repo edit "$github_username/$app_name" --default-branch develop 2>/dev/null || true
        
        print_success "GitHub integration completed!"
        echo -e "${CYAN}🔗 Repository URL:${NC} https://github.com/$github_username/$app_name"
        return 0
    else
        print_error "Failed to push to GitHub"
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
        read -p "Do you want to continue with GitHub setup? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Exiting..."
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
        if bench --site dev.localhost install-app "$app_name" 2>/dev/null; then
            print_success "App installed to development site"
        else
            print_warning "App might already be installed"
        fi
    fi
    
    # Navigate to app directory
    cd "apps/$app_name"
    
    # Initialize git if not already done
    if [[ ! -d ".git" ]]; then
        print_info "Initializing Git repository..."
        git init
        git add .
        git commit -m "Initial commit: Frappe app $app_name"
    fi
    
    # Setup GitHub if requested
    if [[ "$create_github_repo" == "true" ]]; then
        if check_github_auth || setup_github_auth_interactive; then
            local github_username=$(get_github_username)
            
            if create_github_repo "$app_name" "$github_username"; then
                setup_git_repository "$app_name" "$github_username"
            else
                print_warning "GitHub repository creation failed, but your app is ready locally!"
                echo ""
                echo -e "${CYAN}Your app is created and installed locally.${NC}"
                echo -e "${CYAN}You can push to GitHub manually later when permissions are fixed.${NC}"
            fi
        else
            print_warning "GitHub integration skipped (not authenticated)"
        fi
    fi
    
    return 0
}

# Clear screen for better UX
clear

# Show welcome banner
print_header "🚀 FRAPPE APP CREATION WIZARD"

echo -e "${CYAN}Welcome to the Frappe app creation wizard!${NC}"
echo -e "${CYAN}This will guide you through creating your first Frappe application.${NC}"
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

case "$create_repo_input" in
    [nN][oO]|[nN])
        CREATE_GITHUB_REPO="false"
        print_info "GitHub integration disabled"
        ;;
    *)
        CREATE_GITHUB_REPO="true"
        print_info "GitHub integration enabled"
        
        # Check if GitHub CLI is installed
        if ! command -v gh &> /dev/null; then
            install_github_cli
        fi
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