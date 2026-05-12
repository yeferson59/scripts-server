# User Management

## Overview
User account management scripts for handling user creation, permissions, and access control.

## Features
- User account creation
- Permission management
- Access control
- SSH key management
- Group management
- Security policies

## Configuration
1. Set user policies:
   ```bash
   ./create-user.sh --set-policies
   ```

2. Configure default permissions:
   ```bash
   ./create-user.sh --default-perms
   ```

3. Setup SSH:
   ```bash
   ./create-user.sh --setup-ssh
   ```

## Usage
1. Create new user:
   ```bash
   ./create-user.sh --create username
   ```

2. List users:
   ```bash
   ./create-user.sh --list-users
   ```

3. View user permissions:
   ```bash
   ./create-user.sh --view-perms username
   ```

4. Modify permissions:
   ```bash
   ./create-user.sh --modify-perms username
   ```

   Non-interactive examples:
   ```bash
   ./create-user.sh --modify-perms username --show
   ./create-user.sh --modify-perms username --grant-admin
   ./create-user.sh --modify-perms username --revoke-admin
   ./create-user.sh --modify-perms username --add-group docker
   ./create-user.sh --modify-perms username --remove-group docker
   ```

5. Manage SSH keys:
   ```bash
   ./create-user.sh --manage-ssh username
   ```
