# Frappe Development Environment with Interactive Setup

A complete development environment for Frappe applications with **interactive app creation wizard** and automatic GitHub integration.

## 🚀 Quick Start

1. **Launch Codespace**: [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new)
2. **Setup GitHub Token**: See [GitHub Token Setup](#github-token-setup) section below
3. **Wait for setup**: Frappe bench initializes automatically (takes ~5 minutes)
4. **Create your app**: When terminal opens, you'll be prompted to create your first app
5. **Start coding**: Your app and GitHub repo are ready!

## 🔐 GitHub Token Setup

GitHub Codespaces have limited permissions by default. To create repositories and push code, you need a Personal Access Token (PAT).

### Creating a Fine-grained Personal Access Token

1. **Go to GitHub Token Settings**
   - Visit: https://github.com/settings/tokens?type=beta
   - Or navigate: GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens

2. **Create New Token**
   - Click "Generate new token"
   - **Name**: `Frappe Codespaces Development`
   - **Expiration**: 90 days (recommended)
   - **Repository access**: All repositories
   - **Permissions**:
     - **Repository permissions**:
       - Contents: Read and Write
       - Metadata: Read
       - Pull requests: Read and Write
       - Actions: Write (optional)
       - Administration: Write (for repo creation)

3. **Generate and Copy Token**
   - Click "Generate token"
   - **IMPORTANT**: Copy the token immediately (starts with `github_pat_`)

### Adding Token to Codespace

#### Option A: As Codespace Secret (Recommended)
1. Go to [Codespace Settings](https://github.com/settings/codespaces)
2. Click "New secret"
3. Name: `GH_PAT`
4. Value: Paste your token
5. Repository access: Select your repositories
6. Restart your Codespace

#### Option B: As Repository Secret
1. Go to your repository settings
2. Settings → Secrets and variables → Codespaces
3. Add new secret named `GH_PAT`
4. Restart Codespace

#### Option C: Manual Export (Temporary)
```bash
export GH_PAT='github_pat_your_token_here'
```

## 🎯 How It Works

### Step 1: Automatic Bench Setup
When you create the Codespace, it automatically:
- ✅ Installs Node.js, npm, and yarn
- ✅ Initializes Frappe bench with develop branch
- ✅ Creates site `dev.localhost` with admin credentials
- ✅ Configures MariaDB and Redis connections
- ✅ Enables developer mode

### Step 2: Interactive App Creation
When you open the terminal for the first time:
- 🎯 You'll see a welcome message
- 📱 You'll be prompted to create your first app
- 🔐 Optional GitHub authentication and repo creation
- 📦 Optional automatic app installation

## ⚙️ Interactive App Creation

When the terminal opens, you'll be guided through:

### 📱 **App Name**
- Enter your desired Frappe app name
- Must be lowercase with underscores only
- Examples: `my_app`, `sales_module`, `crm_system`

### 🏗️ **GitHub Repository**
- Choose whether to create a private GitHub repository
- If enabled, authenticate with GitHub and push code automatically
- If disabled, you'll have a local Git repository only

### 📦 **App Installation**
- Choose whether to install the app to dev.localhost automatically
- If disabled, you can install manually later

## 🛠️ Manual App Creation

If you skip the initial prompt or want to create additional apps:

```bash
# Run the app creation wizard anytime
create-app

# Or use the full path
/workspace/scripts/create-app-interactive.sh
```

## 🤖 Non-Interactive Mode

For automated setups, you can bypass all prompts:

```bash
# Create app without prompts
cd /workspace/frappe-bench
bench new-app my_custom_app
bench --site dev.localhost install-app my_custom_app

# Setup GitHub manually if needed
cd apps/my_custom_app
git init
git add .
git commit -m "Initial commit"
gh repo create my_custom_app --private
git push -u origin main
```

## 🎮 Development Workflow

### Starting Development Server
```bash
cd /workspace/frappe-bench
bench start
```

### Accessing Your Application
- **Site URL**: http://localhost:8000
- **Username**: Administrator
- **Password**: admin

### Creating Additional Apps
```bash
# Use the interactive wizard
create-app

# Or manually
cd /workspace/frappe-bench
bench new-app another_app
bench --site dev.localhost install-app another_app
```

## 🐛 VS Code Debugging

Pre-configured debug configurations in `.vscode/launch.json`:
1. **Bench Web** - Debug the Frappe web server
2. **Bench Default Worker** - Debug default queue worker
3. **Bench Short Worker** - Debug short queue worker
4. **Bench Long Worker** - Debug long queue worker
5. **Honcho SocketIO Watch Schedule Worker** - Debug all services

To use debugger:
1. Remove `bench serve` from Procfile if present
2. Select debug configuration from VS Code Run panel
3. Set breakpoints in your Python code
4. Start debugging with F5

## 📊 What Gets Created

### After Bench Setup (Automatic)
```
/workspace/
├── frappe-bench/          # Frappe bench directory
│   ├── apps/
│   │   └── frappe/       # Core Frappe framework
│   ├── sites/
│   │   └── dev.localhost/# Development site
│   ├── env/              # Python virtual environment
│   └── Procfile          # Process configuration
└── scripts/
    ├── init-bench-only.sh        # Bench setup script
    ├── create-app-interactive.sh # App creation wizard
    └── setup-terminal.sh         # Terminal configuration
```

### After App Creation (Interactive)
```
/workspace/frappe-bench/apps/
└── your_app_name/         # Your custom app
    ├── .git/              # Git repository
    ├── your_app_name/     # Python package
    ├── license.txt        # MIT License
    ├── README.md          # App documentation
    └── setup.py           # Python setup file
```

### GitHub Repository (Optional)
- **URL**: `https://github.com/your-username/your-app-name`
- **Visibility**: Private
- **Default Branch**: `develop`
- **License**: MIT
- **Gitignore**: Python template

## 🔧 Environment Details

### Pre-installed VS Code Extensions
- Python support with IntelliSense
- Live Server for static content
- Excel viewer for data files
- SQLTools with MariaDB connection
- GitHub Pull Request and Issues
- GitHub theme

### Database Connection
Pre-configured SQLTools connection:
- **Host**: mariadb
- **Port**: 3306
- **Username**: root
- **Password**: 123

### Services
Docker containers running:
- **MariaDB 10.6** - Database server
- **Redis Alpine** - Cache, queue, and socketio

## 🚦 Troubleshooting

### GitHub Authentication Issues

**"remote: invalid credentials" Error**

This happens when using fine-grained PATs incorrectly. Fix:

```bash
# Set your PAT
export GH_PAT='github_pat_your_token_here'

# Navigate to your app
cd /workspace/frappe-bench/apps/your_app_name

# Push using the correct format
git remote set-url origin https://your-username:${GH_PAT}@github.com/your-username/your_app_name.git
git push -u origin develop
git remote set-url origin https://github.com/your-username/your_app_name.git
```

### GitHub Permissions Issue (403 Error)

**Problem**: "Resource not accessible by integration" when creating repository

**Solution 1 - Use Personal Access Token:**
1. Create a fine-grained PAT with proper permissions (see [GitHub Token Setup](#github-token-setup))
2. Add as `GH_PAT` secret in Codespace settings
3. Restart Codespace

**Solution 2 - Manual Repository Creation:**
```bash
# Create repository on GitHub.com first, then:
cd /workspace/frappe-bench/apps/your_app_name
/workspace/scripts/push-to-github.sh
```

### App Creation Issues

**If the welcome prompt doesn't appear:**
```bash
# Run the app creation wizard manually
create-app
```

**If app creation fails:**
```bash
# Check logs
cd /workspace/frappe-bench
bench --site dev.localhost console

# Try manual creation
bench new-app my_app --no-git
cd apps/my_app
git init
git add .
git commit -m "Initial commit"
```

### Development Server Issues

**Port already in use:**
```bash
# Kill existing processes
pkill -f "bench serve"
pkill -f "bench watch"

# Restart
bench start
```

**Database connection failed:**
```bash
# Check MariaDB container
docker ps
docker-compose restart mariadb

# Wait and retry
sleep 10
bench start
```

## 📚 Resources

- [Frappe Framework Documentation](https://frappeframework.com/docs)
- [Frappe App Development Tutorial](https://frappeframework.com/docs/v14/user/en/tutorial)
- [Frappe Community Forum](https://discuss.frappe.io/)
- [ERPNext Example](https://github.com/frappe/erpnext)

## 🤝 Contributing

To improve this setup:
1. Fork this repository
2. Make your changes
3. Test in a new Codespace
4. Submit a pull request

## 📄 License

MIT License - see [license.txt](license.txt) for details.

---

**Happy Frappe Development!** 🎉