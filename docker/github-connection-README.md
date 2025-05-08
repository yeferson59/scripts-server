# Connecting Server with GitHub Repository

This guide explains how to set up and maintain a connection between your server and GitHub for file synchronization.

## Prerequisites

- A GitHub account
- Server with SSH access
- Git installed on the server
- Sudo/root privileges

## Step-by-Step Setup Guide

### 1. Install Git (if not installed)
```bash
# For Debian/Ubuntu
sudo apt-get update
sudo apt-get install git -y

# For RHEL/CentOS
sudo yum install git -y
```

### 2. Configure Git Global Settings
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 3. Generate SSH Key
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Start SSH agent
eval "$(ssh-agent -s)"

# Add SSH key to agent
ssh-add ~/.ssh/id_ed25519
```

### 4. Add SSH Key to GitHub
1. Display your public SSH key:
```bash
cat ~/.ssh/id_ed25519.pub
```
2. Copy the output
3. Go to GitHub → Settings → SSH and GPG keys → New SSH key
4. Paste your key and save

### 5. Test GitHub Connection
```bash
ssh -T git@github.com
```

### 6. Clone Your Repository
```bash
# Clone with SSH URL
git clone git@github.com:username/repository.git
```

### 7. Basic Git Operations

#### Pull from GitHub
```bash
git pull origin main
```

#### Push to GitHub
```bash
git add .
git commit -m "Your commit message"
git push origin main
```

## Automation Scripts

The following scripts are provided to automate common GitHub operations:

### github-sync.sh
- Automatically syncs local changes with GitHub
- Handles both push and pull operations
- Includes error handling and logging

### github-setup.sh
- Automates the initial setup process
- Configures Git and generates SSH key
- Guides through GitHub key addition

## Usage

1. Initial Setup:
```bash
./github-setup.sh
```

2. Sync Files:
```bash
./github-sync.sh
```

## Troubleshooting

### Common Issues

1. Permission Denied
- Verify SSH key is added to GitHub
- Check SSH agent is running
- Ensure correct repository permissions

2. Failed to Push/Pull
- Check internet connection
- Verify repository URL
- Resolve any merge conflicts

3. Authentication Failed
- Regenerate SSH key
- Update GitHub SSH key
- Verify Git configuration

## Security Best Practices

1. Use SSH keys instead of passwords
2. Keep private keys secure
3. Use specific repository permissions
4. Regularly update access credentials
5. Monitor GitHub access logs

## Maintenance

1. Regularly update Git
2. Review and rotate SSH keys
3. Monitor disk space
4. Clean up old branches
5. Review access logs

## Support

For issues or questions:
1. Check logs in `/var/log/github-sync/`
2. Review GitHub status
3. Contact system administrator

