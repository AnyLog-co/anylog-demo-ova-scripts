#!/bin/bash

# setup initial license key
ENV_FILE="~/Anylog/Anylog/ALinstall.env
# Ensure ile exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found."
    exit 1
fi

# Load env variables
set -a
source $ENV_FILE
set +a
IP_ADDR=$(ip -4 addr show "$NIC_TYPE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# Extract current LICENSE_KEY value
CURRENT_KEY=$(grep '^LICENSE_KEY=' "$ENV_FILE" | cut -d '"' -f2)

# If variable not found
if ! grep -q '^LICENSE_KEY=' "$ENV_FILE"; then
    echo "LICENSE_KEY variable not found in $ENV_FILE"
    exit 1
fi

# If blank → prompt user
if [ -z "$CURRENT_KEY" ]; then
    echo "LICENSE_KEY is currently blank."
    echo "You can request a new license key at https://www.anylog.network/download"
    read -p "Please enter your new LICENSE_KEY: " NEW_KEY

    # Ensure user entered something
    if [ -z "$NEW_KEY" ]; then
        echo "No key entered. Exiting."
        exit 1
    fi

    # Replace LICENSE_KEY="" with new key
    sed -i "s|^LICENSE_KEY=\"\"|LICENSE_KEY=\"$NEW_KEY\"|" "$ENV_FILE"

    echo "LICENSE_KEY updated successfully."
else
    echo "LICENSE_KEY already set. No action needed."
fi
# Start Edgelake Services
cd ~/Anylog/node/docker-compose
sudo make up ANYLOG_TYPE=anylog-standalone
sudo make up ANYLOG_TYPE=anylog-operator
sudo docker run -it -d -p 3001:3001 -p 8000:8000 --restart unless-stopped -e REACT_APP_API_URL=http://"$IP_ADDR":8000 --name gui-1 anylogco/anylog-gui

# start sample grafana dashboard
sudo docker run -it -d -p 3000:3000 --restart unless-stopped -e DATASOURCE_URL=http://"$IP_ADDR":32349 --name grafana anylogco/oh-grafana:latest
