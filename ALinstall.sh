#!/bin/bash

# load env vars
set -a
source ./ALinstall.env
set +a
NIC_TYPE=$(ip route | grep default | awk '{print $5}')
IP_ADDR=$(ip -4 addr show "$NIC_TYPE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# Cross-platform in-place sed (GNU/BSD)
sedi() { # usage: sedi 's|^KEY=.*$|KEY=VALUE|' file
  if sed --version &>/dev/null; then sed -i "$1" "$2"; else sed -i '' "$1" "$2"; fi
}

# Replace KEY=... if present, otherwise append KEY=VALUE
ensure_kv() { # KEY VALUE FILE
  local k="$1" v="$2" f="$3"
  [[ -f "$f" ]] || : > "$f"
  if grep -qE "^${k}=" "$f"; then
    sedi "s|^${k}=.*$|${k}=${v}|" "$f"
  else
    printf '\n%s=%s\n' "$k" "$v" >> "$f"
  fi
}

# Apply all ALinstall.env variables (except TAG and COMPOSE_VER) to the node config files.
# Advance-config keys are written to AENV; all others go to base ENV.
# Node-specific overrides set before this call are NOT re-applied here — they are already correct.
apply_env_to_configs() { # BASE_CONFIG_FILE ADVANCE_CONFIG_FILE
  local base_cfg="$1" adv_cfg="$2"
  local skip_keys="TAG|COMPOSE_VER"
  # Keys that belong in advance_configs.env
  local adv_keys="NIC_TYPE|ENABLE_MQTT|MQTT_BROKER|MSG_DBMS|NODE_MONITORING|STORE_MONITORING|SYSLOG_MONITORING|DOCKEER_MONITORING"
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # Skip blank lines and comments
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    # Strip whitespace from key
    key="${key//[[:space:]]/}"
    [[ -z "$key" ]] && continue
    # Skip TAG and COMPOSE_VER
    [[ "$key" =~ ^($skip_keys)$ ]] && continue
    # Route to advance or base config
    if [[ "$key" =~ ^($adv_keys)$ ]]; then
      ensure_kv "$key" "$value" "$adv_cfg"
    else
      ensure_kv "$key" "$value" "$base_cfg"
    fi
  done < ./ALinstall.env
}

do_install() {
  set -e

# If docker, docker-compose and make are already installed via APT or another method, you can skip this step.
  sudo snap install docker
  sudo apt-get -y install make gettext rsyslog

# start syslog
  sudo systemctl enable rsyslog
  sudo systemctl start rsyslog
 
# Grant non-root user permissions to use docker
#  USER=`whoami`
#  groupadd docker
#  usermod -aG docker ${USER}
#  newgrp docker

# Install startup scripts
mkdir -p ~/.config/autostart
cp startup-readme.desktop ~/.config/autostart/

# create log directory
  mkdir -p ~/Anylog/logs

#  Install node
  mkdir -p ~/Anylog/node
  cd ~/Anylog/node
  git clone -b "${COMPOSE_VER}" https://github.com/anylog-co/docker-compose
  cd docker-compose
  docker login -u anyloguser -p dckr_pat_tWYofE1Jx68FXXE9kisQONXE2Sw  

# edit Makefile
#  sed -i 's/-it/-d/g' Makefile
  sedi "s/^export TAG ?= .*/export TAG ?= ${TAG}/" Makefile

  h="$(hostname)"
  
  # forward syslog to anylog
  sudo tee /etc/rsyslog.d/60-custom-forwarding.conf > /dev/null <<EOF
template(name="MyCustomTemplate" type="string" string="<%PRI%>%TIMESTAMP% %HOSTNAME% %syslogtag% %msg%\\n")
*.* action(type="omfwd" target="${IP_ADDR}" port="32150" protocol="tcp" template="MyCustomTemplate")
EOF
  sudo systemctl restart rsyslog

for NODE_TYPE in anylog-standalone-operator anylog-operator; do
  echo "Installing node: $NODE_TYPE"
  
  case "$NODE_TYPE" in
  anylog-standalone-operator)
      ENV="docker-makefiles/${NODE_TYPE}/base_configs.env"
      AENV="docker-makefiles/${NODE_TYPE}/advance_configs.env"
      # Node-specific keys that cannot be derived from ALinstall.env directly
      ensure_kv "NODE_NAME"    "${h}-standalone"          "$ENV"
      ensure_kv "LEDGER_CONN"  "${IP_ADDR}:32148"         "$ENV"
      ensure_kv "CLUSTER_NAME" "${h}-standalone-cluster"  "$ENV"
      #ensure_kv "ENABLE_EXTERNAL_DNS" "${ENABLE_EXTERNAL_DNS}" "$ENV"
      #ensure_kv "ENABLE_DNS"  "${ENABLE_DNS}"             "$ENV"
      #ensure_kv "DNS_DOMAIN"  "${DNS_DOMAIN}"             "$ENV"
      # Apply all remaining ALinstall.env vars to the config files
      apply_env_to_configs "$ENV" "$AENV"

      #make up ANYLOG_TYPE="${NODE_TYPE}"
      ;;

  anylog-operator)
      ENV="docker-makefiles/${NODE_TYPE}/base_configs.env"
      AENV="docker-makefiles/${NODE_TYPE}/advance_configs.env"
      # Node-specific keys — operator uses different ports and disables REST/broker binds
      ensure_kv "NODE_NAME"          "${h}-operator"         "$ENV"
      ensure_kv "LEDGER_CONN"        "${IP_ADDR}:32148"      "$ENV"
      ensure_kv "CLUSTER_NAME"       "${h}-operator-cluster" "$ENV"
      ensure_kv "REST_BIND"          "false"                  "$ENV"
      ensure_kv "BROKER_BIND"        "false"                  "$ENV"
      ensure_kv "ANYLOG_SERVER_PORT" "${ANYLOG_SERVER_PORT}"  "$ENV"
      ensure_kv "ANYLOG_REST_PORT"   "${ANYLOG_REST_PORT}"    "$ENV"
      ensure_kv "ANYLOG_BROKER_PORT" "${ANYLOG_BROKER_PORT}"  "$ENV"
      #ensure_kv "ENABLE_EXTERNAL_DNS" "${ENABLE_EXTERNAL_DNS}" "$ENV"
      #ensure_kv "ENABLE_DNS"         "${ENABLE_DNS}"          "$ENV"
      #ensure_kv "DNS_DOMAIN"         "${DNS_DOMAIN}"          "$ENV"
      ensure_kv "MONITOR_NODES"      "true"                   "$ENV"
      # Apply all remaining ALinstall.env vars to the config files
      apply_env_to_configs "$ENV" "$AENV"

      #make up ANYLOG_TYPE="${NODE_TYPE}"
      ;;

  *)
      echo "ERROR: Unknown NODE_TYPE '$NODE_TYPE' (expected 'anylog-standalone-operator', 'anylog-operator')." >&2
      exit 1
      ;;
  esac

  echo "Node up for NODE_TYPE=$NODE_TYPE"
  done
}

do_uninstall () {

cd ~/Anylog/node/docker-compose

for NODE_TYPE in anylog-standalone-operator anylog-operator; do

  case "$NODE_TYPE" in
  anylog-standalone-operator)
    sudo make clean ANYLOG_TYPE="${NODE_TYPE}"
    sudo docker kill gui-1
    sudo docker rm gui-1
    sudo docker rmi anylogco/remote-gui:beta2
    sudo docker kill grafana
    sudo docker rm grafana
    sudo docker rmi anylogco/oh-grafana:latest
    ;;

  anylog-operator)
    sudo make clean ANYLOG_TYPE="${NODE_TYPE}"
    ;;

  *)
    echo "ERROR: Unknown NODE_TYPE '$NODE_TYPE' (expected 'anylog-standalone-operator'  or  'anylog-operator')." >&2
    exit 1
    ;;

  esac
done  

sudo rm -r ~/Anylog/node

}

do_update() {
  echo "=== Update: starting uninstall ==="
  do_uninstall
  echo "=== Update: uninstall complete, starting install ==="
  do_install
  echo "=== Update: complete ==="
}

case "$1" in
  install)   do_install ;;
  uninstall) do_uninstall ;;
  update)    do_update ;;
  *)
    echo "ERROR: Excpected $0 [install,uninstall,update]" >&2
    exit 1
  ;;

esac
