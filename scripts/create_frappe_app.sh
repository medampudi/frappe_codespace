#!/bin/bash

# create_frappe_app.sh - Create a new Frappe app with GitHub integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to validate app name
validate_app_name() {
    local app_name="$1"
    
    if [[ ! "$app_name" =~ ^[a-z][a-z0-9_]*$ ]]; then
        print_error "Invalid app name. App name should:"
        echo "  - Start with a lowercase letter"
        echo "  - Contain only lowercase letters, numbers, and underscores"
        echo "  - Example: my_app, sales_module, crm_system"
        return 1
    fi
    
    return 0
}

# Function to setup GitHub authentication
setup_github_auth() {
    print_status "Setting up GitHub authentication..."
    
    if gh auth status &> /dev/null; then
        print_success "GitHub CLI already authenticated"
        return 0
    fi
    
    print_status "Please authenticate with GitHub CLI"
    echo "This will open your browser for authentication..."
    echo ""
    
    # Login with required scopes
    if gh auth login --scopes 'repo,workflow,write:packages' --web; then
        print_success "GitHub authentication completed"
        return 0
    else
        print_error "GitHub authentication failed"
        return 1
    fi
}

# Function to create and setup the app
create_frappe_app() {
    local app_name="$1"
    
    print_status "Creating Frappe app: $app_name"
    
    # Navigate to bench directory
    cd /workspace/frappe-bench
    
    # Check if app already exists
    if [[ -d "apps/$app_name" ]]; then
        print_warning "App $app_name already exists"
        read -p "Do you want to continue with GitHub setup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Exiting..."
            exit 0
        fi
    else
        # Create new app
        print_status "Creating new Frappe app..."
        bench new-app "$app_name"
        
        # Install app to site
        print_status "Installing app to dev.localhost..."
        bench --site dev.localhost install-app "$app_name"
    fi
    
    # Navigate to app directory
    cd "apps/$app_name"
    
    # Setup GitHub integration
    setup_github_integration "$app_name"
}

# Function to setup GitHub integration
setup_github_integration() {
    local app_name="$1"
    local github_username
    
    # Get GitHub username
    github_username=$(gh api user --jq '.login')
    
    print_status "Setting up GitHub integration for user: $github_username"
    
    # Create GitHub repository
    print_status "Creating private GitHub repository..."
    
    if gh repo view "$github_username/$app_name" &> /dev/null; then
        print_warning "Repository $app_name already exists"
    else
        gh repo create "$app_name" \
            --private \
            --description "Frappe application: $app_name" \
            --gitignore Python \
            --license MIT
        print_success "Repository created: https://github.com/$github_username/$app_name"
    fi
    
    # Initialize git if not already done
    if [[ ! -d ".git" ]]; then
        print_status "Initializing Git repository..."
        git init
        git add .
        git commit -m "Initial commit: Frappe app $app_name"
    fi
    
    # Create develop branch
    print_status "Setting up develop branch..."
    git checkout -b develop 2>/dev/null || git checkout develop
    
    # Setup remote
    print_status "Setting up remote origin..."
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://github.com/$github_username/$app_name.git"
    
    # Push to GitHub
    print_status "Pushing to GitHub..."
    git push -u origin develop
    
    # Set develop as default branch
    print_status "Setting develop as default branch..."
    gh repo edit "$github_username/$app_name" --default-branch develop
    
    print_success "GitHub integration completed!"
    echo ""
    echo "📊 Summary:"
    echo "  🔗 Repository: https://github.com/$github_username/$app_name"
    echo "  🌿 Default branch: develop"
    echo "  📁 Local path: /workspace/frappe-bench/apps/$app_name"
    echo ""
    echo "🚀 Next steps:"
    echo "  1. Start development server: cd /workspace/frappe-bench && bench start"
    echo "  2. Access your site: http://localhost:8000"
    echo "  3. Login with: Administrator / admin"
    echo "  4. Start coding in: apps/$app_name"
}

# Main script
main() {
    echo "🚀 Frappe App Creator with GitHub Integration"
    echo "=============================================="
    echo ""
    
    # Get app name
    if [[ -z "$1" ]]; then
        echo "Please enter the name for your new Frappe app:"
        read -r app_name
    else
        app_name="$1"
    fi
    
    # Validate app name
    if ! validate_app_name "$app_name"; then
        exit 1
    fi
    
    print_status "App name: $app_name"
    echo ""
    
    # Setup GitHub authentication
    if ! setup_github_auth; then
        print_error "Cannot proceed without GitHub authentication"
        exit 1
    fi
    
    echo ""
    
    # Create the app
    create_frappe_app "$app_name"
    
    echo ""
    print_success "All done! Happy coding! 🎉"
}

# Run main function with all arguments
main "$@"
