
#!/bin/bash
# Start Edgelake Services
cd ~/Anylog/node/docker-compose
make up EDGELAKE_TYPE=master
make up EDGELAKE_TYPE=operator
make up EDGELAKE_TYPE=operator2
make up EDGELAKE_TYPE=query

# Load env variables
set -a
source ~/Anylog/Anylog/ALinstall.env
set +a
IP_ADDR=$(ip -4 addr show "$NIC_TYPE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# start sample grafana dashboard
docker run -it -d -p 3000:3000 --restart unless-stopped -e DATASOURCE_URL=http://"$IP_ADDR":32349 --name grafana anylogco/oh-grafana:latest
