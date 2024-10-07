#!/bin/bash
# This script is used to setup the new VPS server
# Firewall - to secure the server, only allow SSH (22), HTTP (80), and HTTPS (443)
# Git - to clone the code
# Curl, wget - to download the files
# Caddy - reverse proxy and load balancer
# Docker - to run the dockerized application
# PM2 - to run the node application
# NVM - install node and npm
# PNPM - nodejs package manager

# Also it will add caddy, pm2, docker to the system startup

# Guideline
# 1. Run automatically
# curl -sL https://raw.githubusercontent.com/davidtranjs/vps-tools/main/vps-setup.sh | bash
# 2. Run manually
# Copy this script to the server with these commands:
# Copy script > nano setup.sh > paste the script > CTRL+X > Y > ENTER
# Run this script with root user
# chmod +x ./setup.sh && ./setup.sh

# Define color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Function to check the last command's status
check_status() {
    if [ $? -eq 0 ]; then
        log "${GREEN}$1 completed successfully.${NC}"
        log "${YELLOW}----------------------------------------${NC}"
    else
        log "${RED}Error: $1 failed. Exiting.${NC}"
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update and upgrade the system
log "${GREEN}Updating and upgrading the system...${NC}"
sudo apt update && sudo apt upgrade -y
check_status "System update and upgrade"

# Install essential tools
log "${GREEN}Checking and installing essential tools...${NC}"
for tool in curl wget git; do
    if command_exists $tool; then
        log "${YELLOW}$tool is already installed.${NC}"
    else
        log "${GREEN}Installing $tool...${NC}"
        sudo apt install -y $tool
        check_status "$tool installation"
    fi
done

# Verify git installation
log "Verifying git installation..."
git --version
check_status "Git verification"

# Install NVM (Node Version Manager)
if command_exists nvm; then
    log "${YELLOW}NVM is already installed.${NC}"
else
    log "${GREEN}Installing NVM...${NC}"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    check_status "NVM installation"
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Install latest Node.js LTS version
if command_exists node; then
    log "${YELLOW}Node.js is already installed.${NC}"
else
    log "${GREEN}Installing latest Node.js LTS version...${NC}"
    nvm install --lts
    check_status "Node.js LTS installation"
fi

# Install pnpm
if command_exists pnpm; then
    log "${YELLOW}pnpm is already installed.${NC}"
else
    log "${GREEN}Installing pnpm...${NC}"
    npm install -g pnpm
    check_status "pnpm installation"
fi

# Install Docker
if command_exists docker; then
    log "${YELLOW}Docker is already installed.${NC}"
else
    log "${GREEN}Installing Docker...${NC}"
    sudo apt install -y apt-transport-https ca-certificates software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce
    sudo usermod -aG docker $USER
    check_status "Docker installation"

    # Enable Docker to start on boot
    log "${GREEN}Enabling Docker to start on boot...${NC}"
    sudo systemctl enable docker
    check_status "Docker auto-start configuration"
fi

# Install Caddy server
if command_exists caddy; then
    log "${YELLOW}Caddy server is already installed.${NC}"
else
    log "${GREEN}Installing Caddy server...${NC}"
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install -y caddy
    check_status "Caddy server installation"

    # Enable Caddy to start on boot
    log "${GREEN}Enabling Caddy to start on boot...${NC}"
    sudo systemctl enable caddy
    check_status "Caddy auto-start configuration"
fi

# Install PM2
if command_exists pm2; then
    log "${YELLOW}PM2 is already installed.${NC}"
else
    log "${GREEN}Installing PM2...${NC}"
    npm install -g pm2
    check_status "PM2 installation"

    # Setup PM2 to start on boot
    log "${GREEN}Setting up PM2 to start on boot...${NC}"
    PM2_PATH=$(which pm2)
    if [ -z "$PM2_PATH" ]; then
        log "${RED}Error: PM2 not found in PATH. Exiting.${NC}"
        exit 1
    fi

    # Use the correct path for PM2
    sudo env PATH=$PATH:$(dirname $PM2_PATH) $PM2_PATH startup systemd -u $USER --hp $HOME
    check_status "PM2 startup configuration"

    # Save the PM2 process list
    log "${GREEN}Saving PM2 process list...${NC}"
    pm2 save
    check_status "PM2 process list save"
fi

# Setup Firewall
log "${GREEN}Setting up firewall rules...${NC}"
if sudo ufw status | grep -q "Status: active"; then
    log "${YELLOW}UFW is already active. Updating rules...${NC}"
else
    log "${GREEN}Configuring UFW...${NC}"
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    sudo ufw --force enable
    check_status "UFW configuration"
fi

# Ensure the rules are set correctly
sudo ufw status numbered | grep -E "22|80|443" || {
    log "${RED}Error: UFW rules not set correctly. Please check manually.${NC}"
    exit 1
}
check_status "Firewall rules verification"

log "${YELLOW}----------------------------------------${NC}"
log "${GREEN}Setup complete! Firewall is active.${NC}"

# This section is optional, it will restart the system to apply all changes
#log "${YELLOW}The system will restart in 5 seconds to apply all changes.${NC}"
#log "${YELLOW}You can cancel this restart by pressing Ctrl+C now.${NC}"

# Wait for 5 seconds, allowing the user to cancel if needed
#sleep 5

#log "${RED}Restarting now...${NC}"

# Trigger an immediate restart
#sudo shutdown -r now
