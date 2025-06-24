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
    # First, check if GH_PAT is available (your custom PAT)
    if [[ -n "$GH_PAT" ]]; then
        print_info "Using GH_PAT for authentication..."
        echo "$GH_PAT" | gh auth login --with-token 2>/dev/null
        if gh auth status &> /dev/null; then
            print_success "Authenticated with GH_PAT"
            return 0
        fi
    fi
    
    # Then check if GITHUB_TOKEN is available (Codespaces default)
    if [[ -n "$GITHUB_TOKEN" ]]; then
        print_info "Using GITHUB_TOKEN for authentication..."
        echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null
        if gh auth status &> /dev/null; then
            # Check if token has repo scope
            if gh auth status 2>&1 | grep -q "repo" || gh repo list --limit 1 &> /dev/null; then
                print_success "Authenticated with GITHUB_TOKEN"
                return 0
            else
                print_warning "GITHUB_TOKEN lacks repository creation permissions"
                return 1
            fi
        fi
    fi
    
    # Check if already authenticated
    if gh auth status &> /dev/null; then
        # Verify token has repo scope
        if gh auth status 2>&1 | grep -q "repo" || gh repo list --limit 1 &> /dev/null; then
            return 0
        else
            print_warning "Current token lacks repository creation permissions"
            return 1
        fi
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
    
    echo -e "${YELLOW}GitHub integration requires authentication with repository permissions.${NC}"
    echo ""
    
    # Check if we're in Codespaces and guide the user
    if [[ -n "$CODESPACES" ]]; then
        echo -e "${CYAN}You're in GitHub Codespaces. Here are your options:${NC}"
        echo ""
        echo -e "${BLUE}Option 1: Use a Personal Access Token (Recommended)${NC}"
        echo "  1. Go to: https://github.com/settings/tokens/new"
        echo "  2. Create a token with 'repo' scope"
        echo "  3. Add it as GH_PAT secret in your Codespace settings"
        echo "  4. Restart the terminal or run: export GH_PAT='your-token'"
        echo ""
        echo -e "${BLUE}Option 2: Use GitHub CLI authentication${NC}"
        echo "  This will open a browser for authentication"
        echo ""
    fi
    
    read -p "Would you like to authenticate with GitHub now? [Y/n]: " auth_choice
    
    case "$auth_choice" in
        [nN][oO]|[nN])
            print_info "Skipping GitHub authentication"
            return 1
            ;;
        *)
            # Try to authenticate with better scopes
            print_info "Opening browser for GitHub authentication..."
            echo -e "${YELLOW}Please complete the authentication in your browser${NC}"
            
            if gh auth login --scopes 'repo,workflow,write:packages,delete_repo' --web; then
                print_success "GitHub authentication completed!"
                return 0
            else
                print_error "GitHub authentication failed"
                echo ""
                echo -e "${YELLOW}Alternative: Set up a Personal Access Token${NC}"
                echo "  1. Create a token at: https://github.com/settings/tokens/new"
                echo "  2. Select 'repo' scope"
                echo "  3. Run: export GH_PAT='your-token-here'"
                echo "  4. Run this script again"
                return 1
            fi
            ;;
    esac
}

# Function to create GitHub repository with better error handling
create_github_repo() {
    local repo_name="$1"
    local github_username="$2"
    
    print_info "Creating private GitHub repository: $repo_name"
    
    # Check if repo already exists
    if gh repo view "$github_username/$repo_name" &> /dev/null; then
        print_warning "Repository $repo_name already exists"
        read -p "Use existing repository? [Y/n]: " use_existing
        case "$use_existing" in
            [nN][oO]|[nN])
                return 1
                ;;
            *)
                return 0
                ;;
        esac
    fi
    
    # Try to create repository with GitHub CLI
    if gh repo create "$repo_name" \
        --private \
        --description "Frappe application: $repo_name" \
        --gitignore Python \
        --license MIT 2>/tmp/gh_error.log; then
        print_success "Repository created: https://github.com/$github_username/$repo_name"
        return 0
    else
        # Analyze the error
        local error_msg=$(cat /tmp/gh_error.log 2>/dev/null || echo "Unknown error")
        
        if echo "$error_msg" | grep -q "HTTP 403" || echo "$error_msg" | grep -q "Resource not accessible"; then
            print_error "Permission denied - token lacks repository creation scope"
            echo ""
            echo -e "${YELLOW}The current token doesn't have permission to create repositories.${NC}"
            echo ""
            echo -e "${CYAN}To fix this:${NC}"
            echo ""
            echo -e "${BLUE}Option 1: Create a Personal Access Token${NC}"
            echo "  1. Go to: https://github.com/settings/tokens/new"
            echo "  2. Name: 'Codespaces Repo Creation'"
            echo "  3. Select scopes: 'repo' (full control of private repositories)"
            echo "  4. Generate token and copy it"
            echo "  5. In Codespace terminal, run:"
            echo "     export GH_PAT='paste-your-token-here'"
            echo "  6. Run this script again"
            echo ""
            echo -e "${BLUE}Option 2: Use the GitHub API directly${NC}"
            echo "  We'll try this now..."
            echo ""
            
            # Try using curl with the token directly
            if [[ -n "$GH_PAT" ]] || [[ -n "$GITHUB_TOKEN" ]]; then
                local token="${GH_PAT:-$GITHUB_TOKEN}"
                print_info "Attempting to create repository using API directly..."
                
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
                local body=$(echo "$response" | head -n-1)
                
                if [[ "$http_code" == "201" ]]; then
                    print_success "Repository created successfully using GitHub API!"
                    return 0
                else
                    print_error "API creation failed with HTTP $http_code"
                    echo "Error: $(echo "$body" | jq -r '.message' 2>/dev/null || echo "$body")"
                fi
            fi
            
            echo ""
            echo -e "${BLUE}Option 3: Create repository manually${NC}"
            echo "  1. Go to: https://github.com/new"
            echo "  2. Repository name: $repo_name"
            echo "  3. Make it private"
            echo "  4. DON'T initialize with README"
            echo "  5. Create repository"
            echo "  6. Come back here and we'll push your code"
            echo ""
            read -p "Have you created the repository manually? [y/N]: " manual_created
            if [[ "$manual_created" =~ ^[Yy]$ ]]; then
                return 0
            fi
        elif echo "$error_msg" | grep -q "Name already exists"; then
            print_error "A repository with this name already exists in your account"
        else
            print_error "Failed to create repository"
            echo "Error: $error_msg"
        fi
        
        return 1
    fi
}

# Function to setup git repository with proper authentication for fine-grained PATs
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
    
    # Add remote origin
    print_info "Adding remote origin..."
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://github.com/$github_username/$app_name.git"
    
    # Configure git credentials for fine-grained PATs
    print_info "Configuring git authentication..."
    
    # Store credentials properly for fine-grained PATs
    local token="${GH_PAT:-$GITHUB_TOKEN}"
    if [[ -n "$token" ]]; then
        # Configure credential helper
        git config --local credential.helper store
        
        # For fine-grained PATs, we need to use username:token format
        # Temporarily add the token to the remote URL for the push
        git remote set-url origin "https://${github_username}:${token}@github.com/${github_username}/${app_name}.git"
    fi
    
    # Push to GitHub
    print_info "Pushing to GitHub..."
    if git push -u origin develop 2>&1; then
        # Set develop as default branch
        gh repo edit "$github_username/$app_name" --default-branch develop 2>/dev/null || true
        
        # Remove token from URL for security
        git remote set-url origin "https://github.com/$github_username/$app_name.git"
        
        # Store credentials for future use
        if [[ -n "$token" ]]; then
            echo "https://${github_username}:${token}@github.com" > ~/.git-credentials
            chmod 600 ~/.git-credentials
        fi
        
        print_success "GitHub integration completed!"
        echo -e "${CYAN}🔗 Repository URL:${NC} https://github.com/$github_username/$app_name"
        return 0
    else
        print_warning "Initial push failed, trying alternative method..."
        
        # Try pushing to main first, then create develop
        if git push -u origin develop:main --force 2>&1; then
            git push origin develop 2>&1 || true
            gh repo edit "$github_username/$app_name" --default-branch develop 2>/dev/null || true
            
            # Remove token from URL
            git remote set-url origin "https://github.com/$github_username/$app_name.git"
            
            # Store credentials
            if [[ -n "$token" ]]; then
                echo "https://${github_username}:${token}@github.com" > ~/.git-credentials
                chmod 600 ~/.git-credentials
            fi
            
            print_success "GitHub integration completed!"
            echo -e "${CYAN}🔗 Repository URL:${NC} https://github.com/$github_username/$app_name"
            return 0
        else
            # Remove token from URL even if push failed
            git remote set-url origin "https://github.com/$github_username/$app_name.git"
            
            print_error "Failed to push to GitHub"
            echo ""
            echo -e "${YELLOW}You can try pushing manually later:${NC}"
            echo "  cd /workspace/frappe-bench/apps/$app_name"
            echo "  git remote set-url origin https://${github_username}:\${GH_PAT}@github.com/${github_username}/$app_name.git"
            echo "  git push -u origin develop"
            echo "  git remote set-url origin https://github.com/${github_username}/$app_name.git"
            return 1
        fi
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

# Check if GitHub CLI is installed
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

# Check for GitHub token
if [[ -n "$GH_PAT" ]]; then
    print_success "GitHub PAT detected"
elif [[ -n "$GITHUB_TOKEN" ]]; then
    print_info "Codespaces GitHub token detected"
else
    print_warning "No GitHub token detected"
    echo -e "${YELLOW}For GitHub integration, you'll need to authenticate or set up a PAT${NC}"
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