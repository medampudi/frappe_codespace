#!/bin/bash

# This script sets up the terminal environment with helpful aliases and welcome message

# Ensure scripts directory exists and has correct permissions
if [ -d /workspace/scripts ]; then
    chmod +x /workspace/scripts/*.sh 2>/dev/null || true
fi

# Add create-app alias
echo 'alias create-app="/workspace/scripts/create-app-interactive.sh"' >> ~/.bashrc

# Add push-to-github alias
echo 'alias push-app="/workspace/scripts/push-to-github.sh"' >> ~/.bashrc

# Add bench shortcuts
echo 'alias b="bench"' >> ~/.bashrc
echo 'alias bs="bench start"' >> ~/.bashrc
echo 'alias bl="bench --site dev.localhost"' >> ~/.bashrc

# Add quick navigation
echo 'alias cdf="cd /workspace/frappe-bench"' >> ~/.bashrc
echo 'alias cda="cd /workspace/frappe-bench/apps"' >> ~/.bashrc

# Add auto-run welcome message on first terminal open
cat >> ~/.bashrc <<'EOF'

# Check if this is the first terminal session
if [ ! -f ~/.first_terminal_shown ] && [ -f /workspace/.bench_setup_complete ]; then
    touch ~/.first_terminal_shown
    
    # Show welcome message
    if [ -f /workspace/.welcome_message ]; then
        cat /workspace/.welcome_message
    fi
    
    # Quick prompt for app creation
    echo ""
    echo -e "\033[0;36m💡 Quick Actions:\033[0m"
    echo "  • Create app: create-app"
    echo "  • Start server: bench start (or bs)"
    echo "  • Navigate to bench: cdf"
    echo ""
    
    # Only ask if no apps exist yet
    if [ ! -d /workspace/frappe-bench/apps/*/setup.py ] 2>/dev/null; then
        read -p "Would you like to create a Frappe app now? [Y/n]: " create_app_choice
        case "$create_app_choice" in
            [nN][oO]|[nN])
                echo ""
                echo "You can create an app anytime by running: create-app"
                ;;
            *)
                /workspace/scripts/create-app-interactive.sh
                ;;
        esac
    fi
fi

# Show current directory in prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
EOF

echo "Terminal environment configured!"