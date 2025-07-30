# Dify Custom RBAC Implementation

🔐 **One-liner automation tool to restrict Dify log access to Owner/Admin only**

> [日本語版はこちら / Japanese Version](README_ja.md)

By default, Dify allows Editor+ users to view workflow and conversation logs. This tool restricts log access to Owner/Admin roles only.

## ✨ Features

- **🚀 One-liner execution**: Complete automation with a single command
- **🔍 Auto environment detection**: Automatically detects Dify installation & Docker containers
- **💾 Safety features**: Automatic backup & complete rollback capability
- **✅ Built-in verification**: Automatic RBAC validation & report generation
- **🛠️ Flexible compatibility**: Multiple patch patterns for various environments

## 📋 Changes Applied

### Backend API Restrictions
- **workflow_app_log.py**: Restrict workflow log access to Owner/Admin
- **conversation.py**: Restrict conversation log access to Owner/Admin (4 API endpoints)
- **Multi-layer defense**: Complete API-level access control

### Security Enhancements
- Unified role validation using `TenantAccountRole.is_privileged_role()`
- Clear access denial with 403 Forbidden responses  
- Appropriate error messages for Editor/Member users

## 📂 File Structure

```
dify-custom-rbac/
├── README.md                    # English documentation
├── README_ja.md                 # Japanese documentation
├── apply-dify-rbac.sh          # 🎯 Main one-liner script
├── dify-integrated-upgrade.sh  # 🔄 Integrated upgrade script
└── .gitignore                   # Git exclusion settings
```

## 🚀 Super Easy Installation

### Prerequisites
- Dify running with Docker Compose (`docker compose`)
- Docker API container operational
- bash environment (Linux/macOS)

### One-Command Execution

```bash
# 1. Download script & set execute permissions
curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/apply-dify-rbac.sh -o apply-dify-rbac.sh
chmod +x apply-dify-rbac.sh

# 2. Fully automated execution (recommended)
./apply-dify-rbac.sh --auto
```

**That's it!** 🎉

### Other Execution Options

```bash
# Step-by-step execution (with confirmations)
./apply-dify-rbac.sh --interactive

# Check current RBAC status only
./apply-dify-rbac.sh --verify-only

# Specify custom Dify path
./apply-dify-rbac.sh --dify-path /custom/path/dify --auto

# Show help
./apply-dify-rbac.sh --help

# Rollback changes
./apply-dify-rbac.sh --rollback
```

## 🎯 Verification

### Role-based Access Control Matrix

| Role | Log API Access | Verification Method | Expected Result |
|------|----------------|-------------------|-----------------|
| **Owner** | ✅ **Allowed** | Access log pages | Normal display |
| **Admin** | ✅ **Allowed** | Access log pages | Normal display |
| **Editor** | ❌ **Denied** | Access log pages | 403 Forbidden / Internal Server Error |
| **Member** | ❌ **Denied** | Access log pages | 403 Forbidden / Internal Server Error |

### Verification Steps

```bash
# 1. Check RBAC status with script
./apply-dify-rbac.sh --verify-only

# 2. Manual testing
# - Login as Owner/Admin and access log pages → OK
# - Login as Editor/Member and access log pages → Error expected
```

## 🔄 Maintenance

### 🎯 Integrated Upgrade (Recommended)

**One-command Dify upgrade with RBAC preservation:**

```bash
# Download integrated upgrade script
curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/dify-integrated-upgrade.sh -o dify-integrated-upgrade.sh
chmod +x dify-integrated-upgrade.sh

# Automated upgrade (recommended)
./dify-integrated-upgrade.sh --auto

# Interactive upgrade (step-by-step)
./dify-integrated-upgrade.sh --interactive

# Preview changes only
./dify-integrated-upgrade.sh --dry-run
```

**Features:**
- 🔄 **Seamless Integration**: Combines Dify upgrade + RBAC preservation
- 💾 **Auto Backup**: Full backup before any changes
- 🛡️ **Safe Rollback**: Automatic recovery if upgrade fails
- ✅ **Verification**: Post-upgrade health checks
- 📊 **Detailed Report**: Complete upgrade documentation

### Manual Dify Update Procedure

```bash
# 1. Rollback current settings
./apply-dify-rbac.sh --rollback

# 2. Update Dify
cd /root/dify  # or your Dify installation directory
git pull origin main
docker compose pull
docker compose up -d

# 3. Re-apply RBAC
cd /path/to/dify-custom-rbac
./apply-dify-rbac.sh --auto

# 4. Verify operation
./apply-dify-rbac.sh --verify-only
```

### Backup Management

```bash
# Check backup directories
ls -la /tmp/dify-rbac-backup-*

# Rollback from specific backup
BACKUP_DIR=/tmp/dify-rbac-backup-20250730-162641
./apply-dify-rbac.sh --rollback
```

## 🔧 Troubleshooting

### Common Issues & Solutions

#### ❌ **Issue 1**: "API container failed to start properly"
```bash
# Solution
docker logs docker-api-1 --tail 50
docker restart docker-api-1
sleep 30
./apply-dify-rbac.sh --verify-only
```

#### ❌ **Issue 2**: Editor can still access logs
```bash
# Solution: Check patch status
./apply-dify-rbac.sh --verify-only

# Re-apply if needed
./apply-dify-rbac.sh --auto
```

#### ❌ **Issue 3**: Admin cannot access logs
```bash
# Solution: Check roles and clear cache
# 1. Verify user role in Dify admin panel
# 2. Clear browser cache
# 3. Try different browser
```

### Log Inspection Commands

```bash
# RBAC-related logs
docker logs docker-api-1 | grep -i "rbac\|forbidden\|privilege"

# General error logs
docker logs docker-api-1 --tail 100

# Container status check
docker ps -f name=docker-api-1
```

## 📊 Monitoring & Security

### Monitoring Recommendations

- **403 Error Count**: Unauthorized access attempts from Editor/Member users
- **Log API Call Frequency**: Detect abnormal access patterns
- **User Role Changes**: Monitor privilege escalation

### Security Best Practices

1. **Regular Verification**: Monthly operation checks
2. **Backup Retention**: Keep last 3 backups
3. **Log Monitoring**: Regular API access log review
4. **Permission Audits**: Periodic user role review

## ⚡ Quick Deploy Guide

### Initial Setup for New Environments

```bash
# One-liner setup
curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/apply-dify-rbac.sh | bash -s -- --auto
```

### CI/CD Integration Example

```yaml
# GitHub Actions example
- name: Apply Dify RBAC
  run: |
    curl -L https://raw.githubusercontent.com/hiroppelx/dify-custom-rbac/main/apply-dify-rbac.sh -o apply-dify-rbac.sh
    chmod +x apply-dify-rbac.sh
    ./apply-dify-rbac.sh --auto
    ./apply-dify-rbac.sh --verify-only
```

## 🌐 Languages

- [English](README.md) - English README (this file)
- [日本語](README_ja.md) - Japanese README

## 📞 Support

- **🐛 Bug Reports**: [Create GitHub Issue](https://github.com/hiroppelx/dify-custom-rbac/issues)
- **💡 Feature Requests**: [Create GitHub Discussion](https://github.com/hiroppelx/dify-custom-rbac/discussions)
- **🔐 Security Issues**: Contact security team directly
- **📖 Japanese Documentation**: [README_ja.md](README_ja.md)

## 🙏 Contributing

Pull requests and feedback are welcome!

### Contributor Quick Start

```bash
# After forking
git clone https://github.com/your-username/dify-custom-rbac.git
cd dify-custom-rbac

# Test in environment
./apply-dify-rbac.sh --interactive

# Create pull request
git checkout -b feature/your-improvement
git commit -m "feat: your improvement"
git push origin feature/your-improvement
```

## ⚖️ License

This project is licensed under Apache License 2.0, same as the Dify project.

---

## 🎉 Summary

**Complete control over Dify log access with just one command!**

```bash
./apply-dify-rbac.sh --auto
```

- ✅ **Safe**: Automatic backup & rollback support
- ✅ **Simple**: One-command execution
- ✅ **Reliable**: Built-in verification & reporting
- ✅ **Flexible**: Support for diverse environments

**🔐 Only Owner/Admin can access logs now!**