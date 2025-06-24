# Frappe Development Environment with Interactive Setup

A complete development environment for Frappe applications with **interactive app creation wizard** and automatic GitHub integration.

## 🚀 Quick Start

1. **Launch Codespace**: [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new)
2. **Wait for setup**: Frappe bench initializes automatically (takes ~5 minutes)
3. **Create your app**: When terminal opens, you'll be prompted to create your first app
4. **Start coding**: Your app and GitHub repo are ready!

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

### GitHub Integration Issues

**Authentication failed:**
```bash
# Re-authenticate with GitHub
gh auth login --scopes 'repo,workflow,write:packages'

# Check status
gh auth status
```

**Repository creation failed:**
```bash
# Create manually
cd /workspace/frappe-bench/apps/your_app
gh repo create your_app --private
git remote add origin https://github.com/username/your_app.git
git push -u origin main
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