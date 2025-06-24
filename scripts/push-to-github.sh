#!/bin/bash

# Helper script to push existing app to GitHub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're in an app directory
if [[ ! -f "setup.py" ]] || [[ ! -d ".git" ]]; then
    print_error "This script must be run from within a Frappe app directory"
    echo "Please navigate to your app directory first:"
    echo "  cd /workspace/frappe-bench/apps/your_app_name"
    exit 1
fi

# Get app name from current directory
APP_NAME=$(basename "$PWD")

echo -e "${CYAN}🚀 GitHub Push Helper for: $APP_NAME${NC}"
echo ""

# Check GitHub authentication
if ! gh auth status &> /dev/null; then
    print_error "Not authenticated with GitHub"
    echo "Please run: gh auth login"
    exit 1
fi

# Get GitHub username
GITHUB_USERNAME=$(gh api user --jq '.login' 2>/dev/null)
if [[ -z "$GITHUB_USERNAME" ]]; then
    print_error "Could not get GitHub username"
    exit 1
fi

print_success "Authenticated as: $GITHUB_USERNAME"
echo ""

# Check if remote already exists
if git remote get-url origin &> /dev/null; then
    print_info "Remote 'origin' already exists:"
    git remote get-url origin
    echo ""
    read -p "Do you want to update it? [y/N]: " update_remote
    if [[ ! "$update_remote" =~ ^[Yy]$ ]]; then
        print_info "Keeping existing remote"
    else
        git remote remove origin
    fi
fi

# Create repository if it doesn't exist
echo -e "${BLUE}Checking GitHub repository...${NC}"
if gh repo view "$GITHUB_USERNAME/$APP_NAME" &> /dev/null; then
    print_success "Repository already exists: https://github.com/$GITHUB_USERNAME/$APP_NAME"
else
    print_info "Repository doesn't exist. Creating..."
    if gh repo create "$APP_NAME" \
        --private \
        --description "Frappe application: $APP_NAME" \
        --gitignore Python \
        --license MIT; then
        print_success "Repository created!"
    else
        print_error "Failed to create repository"
        echo ""
        echo "Please create the repository manually on GitHub:"
        echo "  1. Go to: https://github.com/new"
        echo "  2. Repository name: $APP_NAME"
        echo "  3. Make it private"
        echo "  4. Don't initialize with README"
        echo ""
        read -p "Press Enter when done..."
    fi
fi

# Add remote if not exists
if ! git remote get-url origin &> /dev/null; then
    print_info "Adding remote origin..."
    git remote add origin "https://github.com/$GITHUB_USERNAME/$APP_NAME.git"
    print_success "Remote added"
fi

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
print_info "Current branch: $CURRENT_BRANCH"

# Push to GitHub
echo ""
print_info "Pushing to GitHub..."
if git push -u origin "$CURRENT_BRANCH"; then
    print_success "Successfully pushed to GitHub!"
    echo ""
    echo -e "${GREEN}🎉 Your app is now on GitHub!${NC}"
    echo -e "${CYAN}Repository URL:${NC} https://github.com/$GITHUB_USERNAME/$APP_NAME"
    echo -e "${CYAN}Clone command:${NC} git clone https://github.com/$GITHUB_USERNAME/$APP_NAME.git"
else
    print_error "Failed to push to GitHub"
    echo ""
    echo "You can try manually:"
    echo "  git push -u origin $CURRENT_BRANCH"
fi