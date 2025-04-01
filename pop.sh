#!/bin/bash

# Script to automate Hemi PoP Miner setup with systemd integration
# Date: April 01, 2025
# Target: Linux (amd64 architecture)
#
# === Credits ===
# Author: MEFURY
# Twitter: https://x.com/meefury

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Directory to work in
WORK_DIR="$HOME/hemi_pop_miner"
MINER_BINARY="popmd"
SERVICE_NAME="hemi-pop-miner.service"

# Function to display credits
display_credits() {
    echo -e "${GREEN}=== Hemi PoP Miner Setup Script with Systemd ===${NC}"
    echo "Date: April 01, 2025"
    echo -e "${GREEN}=== Credits ===${NC}"
    echo "Author: MEFURY"
    echo "Twitter: https://x.com/meefury"
    echo ""
}

# Function to check and stop existing miner (systemd or standalone)
check_and_stop_miner() {
    echo "Checking if PoP Miner is running as a systemd service..."
    if systemctl is-active "$SERVICE_NAME" > /dev/null 2>&1; then
        echo -e "${RED}PoP Miner service ($SERVICE_NAME) is running. Stopping it...${NC}"
        sudo systemctl stop "$SERVICE_NAME"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to stop $SERVICE_NAME. Please stop it manually and rerun the script.${NC}"
            exit 1
        fi
        sudo systemctl disable "$SERVICE_NAME" 2>/dev/null
        echo -e "${GREEN}PoP Miner service stopped and disabled successfully.${NC}"
    else
        echo "No $SERVICE_NAME service detected."
    fi

    echo "Checking for standalone PoP Miner processes..."
    if pgrep -f "$MINER_BINARY" > /dev/null; then
        echo -e "${RED}Standalone PoP Miner process detected. Killing it...${NC}"
        pkill -f "$MINER_BINARY"
        sleep 2 # Wait for process to terminate
        if pgrep -f "$MINER_BINARY" > /dev/null; then
            echo -e "${RED}Failed to kill standalone PoP Miner. Please stop it manually and rerun the script.${NC}"
            exit 1
        else
            echo -e "${GREEN}Standalone PoP Miner stopped successfully.${NC}"
        fi
    else
        echo "No standalone PoP Miner processes detected."
    fi
}

# Function to get the latest release version from GitHub
get_latest_version() {
    echo "Fetching the latest Hemi PoP Miner version from GitHub..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/hemilabs/heminetwork/releases/latest | grep "tag_name" | cut -d'"' -f4)
    if [ -z "$LATEST_VERSION" ]; then
        echo -e "${RED}Failed to fetch latest version. Please check your internet connection or GitHub API status.${NC}"
        exit 1
    fi
    echo "Latest version: $LATEST_VERSION"
}

# Function to download and extract the latest version
download_and_extract() {
    DOWNLOAD_URL="https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz"
    ARCHIVE_FILE="heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz"

    echo "Downloading $ARCHIVE_FILE..."
    curl -L -o "$ARCHIVE_FILE" "$DOWNLOAD_URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Download failed. Please check the URL or your connection.${NC}"
        exit 1
    fi

    echo "Extracting files..."
    tar xvf "$ARCHIVE_FILE"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Extraction failed. Ensure tar is installed and the file is valid.${NC}"
        exit 1
    fi

    # Clean up
    rm "$ARCHIVE_FILE"
    echo -e "${GREEN}Download and extraction completed.${NC}"
}

# Function to prompt for user input
get_user_input() {
    echo "Please provide the following details:"
    read -p "Enter your Bitcoin private key: " BTC_PRIVKEY
    if [ -z "$BTC_PRIVKEY" ]; then
        echo -e "${RED}Private key cannot be empty. Exiting.${NC}"
        exit 1
    fi

    read -p "Enter gas fee rate (sats/vB, e.g., 5): " STATIC_FEE
    if ! [[ "$STATIC_FEE" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Gas fee must be a positive integer. Exiting.${NC}"
        exit 1
    fi
}

# Function to set up and start miner as a systemd service
setup_systemd_service() {
    echo "Setting up systemd service for PoP Miner..."

    # Ensure the miner binary is executable
    cd "$WORK_DIR/heminetwork_${LATEST_VERSION}_linux_amd64" || {
        echo -e "${RED}Failed to navigate to miner directory.${NC}"
        exit 1
    }
    chmod +x "$MINER_BINARY"

    # Create systemd service file
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Hemi PoP Miner Service
After=network.target

[Service]
Environment="POPM_BTC_PRIVKEY=$BTC_PRIVKEY"
Environment="POPM_STATIC_FEE=$STATIC_FEE"
Environment="POPM_BFG_URL=wss://pop.hemi.network/v1/ws/public"
Environment="POPM_BTC_CHAIN_NAME=mainnet"
WorkingDirectory=$WORK_DIR/heminetwork_${LATEST_VERSION}_linux_amd64
ExecStart=$WORK_DIR/heminetwork_${LATEST_VERSION}_linux_amd64/$MINER_BINARY
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create systemd service file. Check your sudo privileges.${NC}"
        exit 1
    fi

    # Reload systemd and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"

    # Check if the service started successfully
    sleep 2
    if systemctl is-active "$SERVICE_NAME" > /dev/null 2>&1; then
        echo -e "${GREEN}PoP Miner service started successfully!${NC}"
    else
        echo -e "${RED}Failed to start PoP Miner service. Check 'sudo systemctl status $SERVICE_NAME' for details.${NC}"
        exit 1
    fi
}

# Main execution
display_credits

# Create working directory
mkdir -p "$WORK_DIR" || {
    echo -e "${RED}Failed to create working directory.${NC}"
    exit 1
}
cd "$WORK_DIR" || {
    echo -e "${RED}Failed to navigate to working directory.${NC}"
    exit 1
}

check_and_stop_miner
get_latest_version
download_and_extract
get_user_input
setup_systemd_service

echo -e "${GREEN}Setup complete! Your Hemi PoP Miner is running as a systemd service.${NC}"
echo "To check the status, use the commands provided below:"
echo "  - Check service status: sudo systemctl status $SERVICE_NAME"
echo "  - View logs: sudo journalctl -u $SERVICE_NAME -f"
echo "  - Stop service: sudo systemctl stop $SERVICE_NAME"
echo "  - Start service: sudo systemctl start $SERVICE_NAME"
