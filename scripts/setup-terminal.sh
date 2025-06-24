#!/bin/bash

# This script sets up the terminal environment with helpful aliases and welcome message

# Ensure scripts directory exists and has correct permissions
if [ -d /workspace/scripts ]; then
    chmod +x /workspace/scripts/*.sh 2>/dev/null || true
fi

# Add create-app alias
echo 'alias create-app="/workspace/scripts/create-app-interactive.sh"' >> ~/.bashrc

# Add auto-run welcome message on first terminal open
cat >> ~/.bashrc <<'EOF'

# Check if this is the first terminal session
if [ ! -f ~/.first_terminal_shown ] && [ -f /workspace/.bench_setup_complete ]; then
    touch ~/.first_terminal_shown
    
    # Show welcome message
    if [ -f /workspace/.welcome_message ]; then
        cat /workspace/.welcome_message
    fi
    
    # Ask if user wants to create an app
    echo ""
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
EOF

echo "Terminal environment configured!"