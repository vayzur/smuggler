# Getting Started

This guide will help you set up Smuggler from scratch.

## Prerequisites

### Control Machine (Your Computer)

- **Operating System**: Linux, macOS, or WSL2
- **Software**:
  - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) >= 2.10
  - SSH client
  - Git

**Install Ansible:**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install ansible

# macOS
brew install ansible

# Using pip
pip install ansible
```

### Target Nodes (Remote Servers)

- **Operating System**: Debian/RedHat-based Linux
- **Requirements**:
  - SSH access with sudo/root privileges
  - Python 3 installed
  - Minimum 512MB RAM
  - Open port 53 (UDP) on server nodes

## Installation

### 1. Clone Repository
```bash
git clone https://github.com/vayzur/smuggler.git
cd smuggler
```

### 2. Verify Ansible
```bash
ansible --version
# Should show version 2.10 or higher
```

### 3. Test SSH Connectivity
```bash
# Test connection to your server
ssh root@your-server-ip

# If using SSH keys, ensure they're loaded
ssh-add ~/.ssh/id_rsa
```

## Binary Management

Smuggler automatically downloads precompiled binaries from GitHub releases during deployment. No manual binary placement is required.

Binaries are downloaded to `/usr/local/bin/` on target nodes during the first deployment.

## Next Steps

1. [Configure your infrastructure](configuration.md)
2. [Set up DNS records](dns-setup.md)
3. [Deploy tunnels](deployment.md)
