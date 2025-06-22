# Frappe Development Environment with GitHub Integration

A complete development environment for Frappe applications with automatic GitHub repository creation and integration.

## 🚀 Quick Start

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new)

# Frappe Development Environment with Interactive Setup

A complete development environment for Frappe applications with **interactive configuration and automatic GitHub integration** during Codespace launch.

## 🚀 Quick Start

1. **Launch Codespace**: [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new)
2. **Configure interactively**: Answer prompts for app name and preferences
3. **Wait for setup**: Everything builds automatically based on your choices
4. **Start coding**: Your app and GitHub repo are ready!

## ⚙️ Interactive Configuration

When you launch the Codespace, you'll be prompted for:

### 📱 **App Name**
- Enter your desired Frappe app name
- Must be lowercase with underscores only
- Examples: `my_app`, `sales_module`, `crm_system`

### 🏗️ **GitHub Repository**
- Choose whether to create a private GitHub repository
- If enabled, your code will be automatically pushed
- If disabled, you'll have a local Git repository only

### 📦 **App Installation**
- Choose whether to install the app to dev.localhost automatically
- If disabled, you can install manually later

## 🤖 Non-Interactive Mode

For automated setups (CI/CD, scripts), you can bypass prompts using environment variables:

```bash
export APP_NAME="my_custom_app"
export CREATE_GITHUB_REPO="true"
export AUTO_INSTALL_APP="true"
``` 🛠️ Setup Process

The setup happens in multiple steps:

### Step 1: Initial Environment Setup
1. GitHub creates and initializes the codespace
2. VSCode UI loads
3. Automatic setup script runs to:
   - Install Node.js, npm, and yarn
   - Initialize Frappe bench with develop branch
   - Create site `dev.localhost` with password `admin`
   - Enable developer mode

### Step 2: Create Your Frappe App
After the initial setup completes, create your app:

```bash
# Make the script executable
chmod +x /workspace/scripts/create_frappe_app.sh

# Create your app (replace 'my_app' with your desired app name)
/workspace/scripts/create_frappe_app.sh my_app
```

The script will:
- ✅ Validate your app name
- 🔐 Setup GitHub CLI authentication
- 📱 Create the Frappe app
- 🏗️ Create a private GitHub repository
- 🌿 Setup develop branch as default
- 📤 Push initial code to GitHub

## 🎯 Features

### Automated Setup
- ✅ **One-click deployment** - Everything configured automatically
- ✅ **Custom app creation** - Your app is created during initialization
- ✅ **GitHub integration** - Repository created and code pushed automatically
- ✅ **Zero manual steps** - Ready to code immediately after startup

### Development Environment
- ✅ Fresh Frappe bench with latest develop code
- ✅ Pre-configured site (dev.localhost) with admin/admin credentials
- ✅ Developer mode enabled for hot reloading
- ✅ All dependencies installed (Node.js, Python, databases)
- ✅ Docker containers for MariaDB and Redis

### GitHub Integration
- ✅ **Automatic authentication** using Codespace GitHub token
- ✅ **Private repository creation** with proper naming
- ✅ **Develop branch** set as default
- ✅ **Initial commit and push** with your app code
- ✅ **Proper Git configuration** with your GitHub credentials

### VS Code Configuration
Pre-configured `launch.json` with:
1. **Web Server** - Debug the Frappe web server
2. **Workers** - Debug background workers (default, short, long)
3. **Full Stack** - Debug socketio, watch, schedule, and workers

### Pre-installed Extensions
- Python support with correct interpreter
- Live Server for static content
- Excel viewer for data files
- SQLTools with MariaDB connection
- GitHub integration tools

## 📱 App Naming Guidelines

Your app name should:
- Start with a lowercase letter
- Contain only lowercase letters, numbers, and underscores
- Be descriptive of your app's purpose

**Valid examples:**
- `my_app`
- `sales_module`
- `crm_system`
- `inventory_management`

**Invalid examples:**
- `MyApp` (uppercase letters)
- `my-app` (hyphens)
- `123app` (starts with number)

## 🔐 GitHub Authentication

The first time you create an app, you'll need to authenticate with GitHub:

1. The script will automatically prompt for authentication
2. It will open your browser for GitHub login
3. Grant the required permissions:
   - `repo` - Create and manage repositories
   - `workflow` - Manage GitHub Actions
   - `write:packages` - Publish packages

## 🚦 Troubleshooting

### GitHub Integration Issues

**If GitHub repository creation fails:**
```bash
# Check authentication status
gh auth status

# Re-authenticate if needed
gh auth login --scopes 'repo,workflow,write:packages'

# Manually create repository for existing app
cd /workspace/frappe-bench/apps/your_app_name
/workspace/scripts/create_frappe_app.sh your_app_name
```

**If you get permission denied (403) errors:**
1. Check your GitHub token has the required scopes
2. Verify Codespace has repository permissions enabled
3. Try re-authenticating: `gh auth refresh`

### App Name Validation Errors
App names must:
- Start with a lowercase letter
- Contain only lowercase letters, numbers, and underscores
- Be descriptive of your app's purpose

**Valid examples:** `my_app`, `sales_module`, `crm_system`
**Invalid examples:** `MyApp`, `my-app`, `123app`

### Setup Process Issues

**If initialization fails or hangs:**
```bash
# Check the creation log
# In VS Code: Ctrl+Shift+P → "Codespaces: View Creation Log"

# Or restart the setup manually
cd /workspace
bash scripts/init.sh your_app_name
```

**If MariaDB connection fails:**
```bash
# Check container status
docker ps

# Restart database
docker-compose restart mariadb

# Wait and try again
cd /workspace/frappe-bench
bench start
```

**If app already exists but GitHub integration is missing:**
The setup script is idempotent - you can run it again:
```bash
cd /workspace
APP_NAME=existing_app bash scripts/init.sh
```

## 🎮 Development Workflow

### After Setup Completes
Everything is ready immediately:
```bash
# Your app is already created and installed
# GitHub repository is set up with develop branch
# Just start the development server:
cd /workspace/frappe-bench
bench start
```

### Accessing Your Application
- **Site URL**: http://localhost:8000
- **Username**: Administrator
- **Password**: admin
- **App Code**: `/workspace/frappe-bench/apps/your_app_name`

### Making Changes and Pushing to GitHub
```bash
cd /workspace/frappe-bench/apps/your_app_name

# Make your changes to the code
# ...

# Commit and push (Git is already configured)
git add .
git commit -m "Add new feature"
git push origin develop
```

### Using the VS Code Debugger
1. Remove `bench serve` from Procfile if present:
   ```bash
   cd /workspace/frappe-bench
   sed -i '/bench serve/d' Procfile
   ```
2. Use VS Code's "Bench Web" debug configuration from the Run panel
3. Set breakpoints in your Python code
4. Access site at http://localhost:8000

### Creating Additional Apps
```bash
cd /workspace/frappe-bench

# Create new app
bench new-app my_second_app

# Install to site
bench --site dev.localhost install-app my_second_app

# Setup GitHub integration (optional)
/workspace/scripts/create_frappe_app.sh my_second_app
```

### Working with Multiple Branches
```bash
cd /workspace/frappe-bench/apps/your_app_name

# Create feature branch
git checkout -b feature/new-functionality

# Work on your feature...
git add .
git commit -m "Implement new functionality"
git push -u origin feature/new-functionality

# Create pull request on GitHub
gh pr create --title "New functionality" --body "Description of changes"
```

## 🌐 Accessing Your Site

- **URL**: http://localhost:8000
- **Username**: Administrator
- **Password**: admin

## 📊 What Gets Created

After successful setup, you'll have:

### Local Development Environment
```
/workspace/
├── frappe-bench/              # Main Frappe bench
│   ├── apps/
│   │   ├── frappe/           # Core Frappe framework
│   │   └── your_app_name/    # Your custom app (with Git repo)
│   ├── sites/
│   │   └── dev.localhost/    # Development site
│   ├── env/                  # Python virtual environment
│   └── Procfile              # Process configuration
├── scripts/
│   ├── init.sh              # Main initialization script
│   └── create_frappe_app.sh # Manual app creation script
└── .devcontainer/           # Container configuration
```

### GitHub Repository
- **URL**: `https://github.com/your-username/your-app-name`
- **Visibility**: Private
- **Default Branch**: `develop`
- **Initial Commit**: Complete Frappe app structure
- **License**: MIT
- **Gitignore**: Python template

### VS Code Workspace
- **Python Interpreter**: Automatically configured to use Frappe's virtual environment
- **Debug Configurations**: Ready-to-use launch configurations for web server and workers
- **Extensions**: Frappe development extensions pre-installed
- **Database Tools**: SQLTools configured for MariaDB access

### Development Site
- **URL**: `http://localhost:8000`
- **Admin User**: Administrator
- **Password**: admin
- **Developer Mode**: Enabled
- **Your App**: Installed and ready to use

## 🔧 Advanced Configuration

### Custom Environment Variables
Set these in your Codespace environment:
- `APP_NAME` - Default app name for automatic creation
- `GITHUB_USERNAME` - Override GitHub username detection

### SQLTools Database Connection
Pre-configured connection details:
- **Host**: mariadb
- **Port**: 3306
- **Username**: root
- **Password**: 123

## 📚 Next Steps

After setup:
1. Read the [Frappe Documentation](https://frappeframework.com/docs)
2. Explore the [Frappe App Development Tutorial](https://frappeframework.com/docs/v14/user/en/tutorial)
3. Check out [ERPNext](https://github.com/frappe/erpnext) as an example app
4. Join the [Frappe Community](https://discuss.frappe.io/)

## 🤝 Contributing

This setup is designed to streamline Frappe development. If you have suggestions or improvements:
1. Fork this repository
2. Make your changes
3. Submit a pull request

## 📄 License

MIT License - see [license.txt](license.txt) for details.

---

**Happy Frappe Development!** 🎉
