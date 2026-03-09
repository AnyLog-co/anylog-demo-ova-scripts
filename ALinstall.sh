#!/bin/bash

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
ENV_FILE="./ALinstall.env"
NODE_LIST_ARG=""
AUTO_START=false
AUTO_STOP=false
DEMO_MODE=false
VALID_NODES="anylog-generic anylog-master anylog-operator anylog-query anylog-publisher anylog-standalone-operator anylog-standalone-publisher"

# ---------------------------------------------------------------------------
# Argument parsing — flags must precede the command verb
# Usage: ALinstall.sh [-e env_file] [-n node1,node2,...] [-s] [-k] [-d] install|uninstall|update|start|stop
# ---------------------------------------------------------------------------
usage() {
  echo "Usage: $0 [-e env_file] [-n node1,node2,...] [-s] [-k] [-d] [install|uninstall|update|start|stop]"
  echo "  -e  Path to environment file (default: ./ALinstall.env)"
  echo "  -n  Comma-delimited list of node types to act on"
  echo "      Valid nodes: ${VALID_NODES}"
  echo "  -s  Automatically start nodes after install or update"
  echo "  -k  Automatically stop nodes before uninstall or update"
  echo "  -d  Demo mode: install/uninstall the full demo environment (overrides -n)"
  exit 1
}

while getopts ":e:n:skd" opt; do
  case "$opt" in
    e) ENV_FILE="$OPTARG" ;;
    n) NODE_LIST_ARG="$OPTARG" ;;
    s) AUTO_START=true ;;
    k) AUTO_STOP=true ;;
    d) DEMO_MODE=true ;;
    :) echo "ERROR: Option -${OPTARG} requires an argument." >&2; usage ;;
    \?) echo "ERROR: Unknown option -${OPTARG}." >&2; usage ;;
  esac
done
shift $((OPTIND - 1))

# -d overrides -n: demo always uses the full node set
if $DEMO_MODE; then
  read -ra NODE_LIST <<< "$VALID_NODES"
elif [[ -n "$NODE_LIST_ARG" ]]; then
  IFS=',' read -ra NODE_LIST <<< "$NODE_LIST_ARG"
  for n in "${NODE_LIST[@]}"; do
    valid=false
    for v in $VALID_NODES; do [[ "$n" == "$v" ]] && valid=true && break; done
    if ! $valid; then
      echo "ERROR: Unknown node type '${n}'. Valid nodes: ${VALID_NODES}" >&2
      exit 1
    fi
  done
else
  read -ra NODE_LIST <<< "$VALID_NODES"
fi

# ---------------------------------------------------------------------------
# Logging — ./logs/ALinstall_<command>_<timestamp>.log
# Captures all output (stdout + stderr) to log file while still printing to
# the terminal. Set up after arg parsing so $1 (command) is available.
# ---------------------------------------------------------------------------
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/ALinstall_${1:-unknown}_$(date '+%Y%m%d_%H%M%S').log"

# Redirect all stdout and stderr through tee into the log file
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "=== ALinstall started: command='${1:-unknown}' env='${ENV_FILE}' nodes='${NODE_LIST[*]}' demo=${DEMO_MODE} ==="
log "Log file: ${LOG_FILE}"

# ---------------------------------------------------------------------------
# Load environment variables
# ---------------------------------------------------------------------------
[[ -f "$ENV_FILE" ]] || { log "ERROR: Environment file not found: $ENV_FILE"; exit 1; }
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

NIC_TYPE=$(ip route | grep default | awk '{print $5}')
IP_ADDR=$(ip -4 addr show "$NIC_TYPE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

log "Detected NIC: ${NIC_TYPE}  IP: ${IP_ADDR}"

# ---------------------------------------------------------------------------
# Cross-platform in-place sed (GNU/BSD)
# ---------------------------------------------------------------------------
sedi() { # usage: sedi 's|^KEY=.*$|KEY=VALUE|' file
  if sed --version &>/dev/null; then sed -i "$1" "$2"; else sed -i '' "$1" "$2"; fi
}

# ---------------------------------------------------------------------------
# Replace KEY=... if present, otherwise append KEY=VALUE
# ---------------------------------------------------------------------------
ensure_kv() { # KEY VALUE FILE
  local k="$1" v="$2" f="$3"
  [[ -f "$f" ]] || : > "$f"
  if grep -qE "^${k}=" "$f"; then
    sedi "s|^${k}=.*$|${k}=${v}|" "$f"
  else
    printf '\n%s=%s\n' "$k" "$v" >> "$f"
  fi
}

# ---------------------------------------------------------------------------
# Apply all env-file variables (except TAG and COMPOSE_VER) to node config files.
# Advance-config keys are written to AENV; all others go to base ENV.
# ---------------------------------------------------------------------------
apply_env_to_configs() { # BASE_CONFIG_FILE 
  local base_cfg="$1" 
  local skip_keys="TAG|COMPOSE_VER"
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    key="${key//[[:space:]]/}"
    [[ -z "$key" ]] && continue
    [[ "$key" =~ ^($skip_keys)$ ]] && continue
      ensure_kv "$key" "$value" "$base_cfg"
    fi
  done < "$ENV_FILE"
}

# ---------------------------------------------------------------------------
# Return only nodes from NODE_LIST whose Docker containers are currently running.
# Prints one node-type per line.
# ---------------------------------------------------------------------------
get_running_anylog_nodes() {
  local running_containers
  running_containers=$(docker ps --format '{{.Names}}' 2>/dev/null)
  if $DEMO_MODE; then
    for NODE_TYPE in anylog-standalone-operator anylog-operator gui-1 grafana"; do
      if echo "$running_containers" | grep -q "${node}"; then
        echo "$node"
      fi
    done

  else

    for node in "${NODE_LIST[@]}"; do
      if echo "$running_containers" | grep -q "${node}"; then
        echo "$node"
      fi
    done
  fi
}

# ---------------------------------------------------------------------------
# START — runs 'make up' for each node in NODE_LIST
# ---------------------------------------------------------------------------
do_start() {
  cd ~/Anylog/node/docker-compose
  if $DEMO_MODE; then
    for NODE_TYPE in anylog-standalone-operator anylog-operator"; do
      log "Starting node: $NODE_TYPE"
      sudo make up ANYLOG_TYPE="${NODE_TYPE}"
      log "Node started: $NODE_TYPE"

# start anylog gui
      log "== starting Anylog Gui =="
      sudo docker run -it -d -p 31800:31800 -p 8080:8080 --restart unless-stopped -e REACT_APP_API_URL=http://"$IP_ADDR":8080 --name gui-1 anylogco/remote-gui:beta2

# start sample grafana dashboard
      log "== starting Grafana =="
      sudo docker run -it -d -p 3000:3000 --restart unless-stopped -e DATASOURCE_URL=http://"$IP_ADDR":32149 --name grafana anylogco/oh-grafana:la

   else
    for NODE_TYPE in "${NODE_LIST[@]}"; do
      log "Starting node: $NODE_TYPE"
      sudo make up ANYLOG_TYPE="${NODE_TYPE}"
      log "Node started: $NODE_TYPE"
    done
}

# ---------------------------------------------------------------------------
# STOP — runs 'make down' for each running node in NODE_LIST
# ---------------------------------------------------------------------------
do_stop() {
  cd ~/Anylog/node/docker-compose

  mapfile -t RUNNING_NODES < <(get_running_anylog_nodes)

  if [[ ${#RUNNING_NODES[@]} -eq 0 ]]; then
    log "No running AnyLog nodes found matching: ${NODE_LIST[*]} — nothing to stop."
    return 0
  fi

  log "Nodes to stop: ${RUNNING_NODES[*]}"
  for NODE_TYPE in "${RUNNING_NODES[@]}"; do
    log "Stopping node: $NODE_TYPE"
    sudo make down ANYLOG_TYPE="${NODE_TYPE}"
    log "Node stopped: $NODE_TYPE"
  done
}

# ---------------------------------------------------------------------------
# INSTALL — configure node(s) and optionally start them.
#   Demo mode (-d): full demo case blocks (gui, grafana, extra services).
#   Default:        lean config using only NODE_LIST entries.
# ---------------------------------------------------------------------------
do_install() {
  set -e

# create log directory
  mkdir -p ~/Anylog/logs

  log "=== Install started (demo=${DEMO_MODE}) ==="

# If docker, docker-compose and make are already installed via APT or another method, you can skip this step.
  log "Installing system packages..."
  sudo snap install docker
  sudo apt-get -y install make gettext rsyslog

# Install node
  log "Cloning docker-compose repo (branch: ${COMPOSE_VER})..."
  mkdir -p ~/Anylog/node
  cd ~/Anylog/node
  git clone -b "${COMPOSE_VER}" https://github.com/anylog-co/docker-compose
  cd docker-compose
  docker login -u anyloguser -p dckr_pat_tWYofE1Jx68FXXE9kisQONXE2Sw

# edit Makefile
#  sed -i 's/-it/-d/g' Makefile
  log "Setting Makefile TAG to ${TAG}..."
  sedi "s/^export TAG ?= .*/export TAG ?= ${TAG}/" Makefile

  h="$(hostname)"
 
if $DEMO_MODE; then
# --- Demo install: full environment including gui, grafana, extra services ---

# start syslog
  log "Enabling rsyslog..."
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

  # forward syslog to anylog
  log "Configuring rsyslog forwarding to ${IP_ADDR}:32160..."
  sudo tee /etc/rsyslog.d/60-custom-forwarding.conf > /dev/null <<EOF
template(name="MyCustomTemplate" type="string" string="<%PRI%>%TIMESTAMP% %HOSTNAME% %syslogtag% %msg%\\n")
*.* action(type="omfwd" target="${IP_ADDR}" port="32160" protocol="tcp" template="MyCustomTemplate")
EOF
  sudo systemctl restart rsyslog

  for NODE_TYPE in anylog-standalone-operator anylog-operator; do
    log "Configuring node: $NODE_TYPE"

      case "$NODE_TYPE" in
      anylog-standalone-operator)
          ENV="docker-makefiles/${NODE_TYPE}/base_configs.env"
          apply_env_to_configs "$ENV" 
          ensure_kv "NODE_NAME"    "${h}-standalone"          "$ENV"
          ensure_kv "LEDGER_CONN"  "${IP_ADDR}:32148"         "$ENV"
          ensure_kv "CLUSTER_NAME" "${h}-standalone-operator-cluster"  "$ENV"
	  ensure_kv "NIC_TYPE"	   "${NIC_TYPE}"	      "$ENV"
	  ensure_kv "LICENSE_KEY"  "$NEW_KEY"		      "$ENV"

          ;;

      anylog-operator)
          ENV="docker-makefiles/${NODE_TYPE}/base_configs.env"
          apply_env_to_configs "$ENV" 
          ensure_kv "NODE_NAME"          "${h}-operator"          "$ENV"
          ensure_kv "LEDGER_CONN"        "${IP_ADDR}:32148"       "$ENV"
          ensure_kv "CLUSTER_NAME"       "${h}-operator-cluster"  "$ENV"
          ensure_kv "ANYLOG_SERVER_PORT" "32158"   		  "$ENV"
          ensure_kv "ANYLOG_REST_PORT"   "32159"	          "$ENV"
          ensure_kv "ANYLOG_BROKER_PORT" "32160"    		  "$ENV"
	  ensure_kv "NIC_TYPE"	   	"${NIC_TYPE}"	          "$ENV"
	  ensure_kv "LICENSE_KEY"  	 "$NEW_KEY"	          "$ENV"

          ;;

      *)
          log "ERROR: Unknown NODE_TYPE '${NODE_TYPE}' in demo install."
          exit 1
          ;;
      esac

    else
      # --- Standard install: configure only the requested node ---
      case "$NODE_TYPE" in
      anylog-generic)
          ENV="docker-makefiles/${NODE_TYPE}/base_configs.env"
          apply_env_to_configs "$ENV" 
          ensure_kv "NODE_NAME"    "${h}-standalone"          "$ENV"
          ensure_kv "LEDGER_CONN"  "${IP_ADDR}:32148"         "$ENV"
	  ensure_kv "NIC_TYPE"	   "${NIC_TYPE}"	      "$ENV"
	  ensure_kv "LICENSE_KEY"  "$NEW_KEY"		      "$ENV"
          ;;

      anylog-master)
          ENV="docker-makefiles/${NODE_TYPE}/base_configs.env"
          apply_env_to_configs "$ENV" 
          ensure_kv "NODE_NAME"    "${h}-master"              "$ENV"
          ensure_kv "LEDGER_CONN"  "${IP_ADDR}:32148"         "$ENV"
	  ensure_kv "NIC_TYPE"	   "${NIC_TYPE}"	      "$ENV"
	  ensure_kv "LICENSE_KEY"  "$NEW_KEY"		      "$ENV"
          ;;

      anylog-operator)
          ENV="docker-makefiles/${NODE_TYPE}/base_configs.env"
          apply_env_to_configs "$ENV" 
          ensure_kv "NODE_NAME"    "${h}-operator"            "$ENV"
          ensure_kv "LEDGER_CONN"  "${IP_ADDR}:32148"         "$ENV"
          ensure_kv "CLUSTER_NAME" "${h}-standalone-cluster"  "$ENV"
	  ensure_kv "NIC_TYPE"	   "${NIC_TYPE}"	      "$ENV"
	  ensure_kv "LICENSE_KEY"  "$NEW_KEY"		      "$ENV"
          ;;

      anylog-pulisher)
          ENV="docker-makefiles/${NODE_TYPE}/base_configs.env"
          apply_env_to_configs "$ENV" 
          ensure_kv "NODE_NAME"    "${h}-publisher"           "$ENV"
          ensure_kv "LEDGER_CONN"  "${IP_ADDR}:32148"         "$ENV"
          ensure_kv "CLUSTER_NAME" "${h}-cluster"  "$ENV"
	  ensure_kv "NIC_TYPE"	   "${NIC_TYPE}"	      "$ENV"
	  ensure_kv "LICENSE_KEY"  "$NEW_KEY"		      "$ENV"
          ;;

      anylog-query)
          ENV="docker-makefiles/${NODE_TYPE}/base_configs.env"
          apply_env_to_configs "$ENV" 
          ensure_kv "NODE_NAME"    "${h}-query"               "$ENV"
          ensure_kv "LEDGER_CONN"  "${IP_ADDR}:32148"         "$ENV"
	  ensure_kv "NIC_TYPE"	   "${NIC_TYPE}"	      "$ENV"
	  ensure_kv "LICENSE_KEY"  "$NEW_KEY"		      "$ENV"
          ;;

      anylog-standalone-operator)
          ENV="docker-makefiles/${NODE_TYPE}/base_configs.env"
          apply_env_to_configs "$ENV" 
          ensure_kv "NODE_NAME"    "${h}-standalone-operator" "$ENV"
          ensure_kv "LEDGER_CONN"  "${IP_ADDR}:32148"         "$ENV"
          ensure_kv "CLUSTER_NAME" "${h}-standalone-operator-cluster"  "$ENV"
	  ensure_kv "NIC_TYPE"	   "${NIC_TYPE}"	      "$ENV"
	  ensure_kv "LICENSE_KEY"  "$NEW_KEY"		      "$ENV"
          ;;

      anylog-standalone-publisher)
          ENV="docker-makefiles/${NODE_TYPE}/base_configs.env"
          apply_env_to_configs "$ENV" 
          ensure_kv "NODE_NAME"    "${h}-standalone-publisher"          "$ENV"
          ensure_kv "LEDGER_CONN"  "${IP_ADDR}:32148"                   "$ENV"
          ensure_kv "CLUSTER_NAME" "${h}-standalone-publisher-cluster"  "$ENV"
	  ensure_kv "NIC_TYPE"	   "${NIC_TYPE}"	      "$ENV"
	  ensure_kv "LICENSE_KEY"  "$NEW_KEY"		      "$ENV"
          ;;

      *)
          log "ERROR: Unknown NODE_TYPE '${NODE_TYPE}'."
          exit 1
          ;;
      esac
    fi

    log "Node configured: $NODE_TYPE"
  done

  if $AUTO_START; then
    log "=== Auto-start: launching nodes ==="
    do_start
  else
    log "Install complete. Run '$0 [-n nodes] start' or re-run with -s to start nodes."
  fi

  log "=== Install complete ==="
}

# ---------------------------------------------------------------------------
# UNINSTALL — only acts on nodes that are currently running.
#   Demo mode (-d): also removes gui, grafana, and demo-specific images.
#   Default:        clean only the node container/stack itself.
# ---------------------------------------------------------------------------
do_uninstall() {
  log "=== Uninstall running nodes (demo=${DEMO_MODE}) ==="

  cd ~/Anylog/node/docker-compose

  # Narrow the target list to nodes actually running in Docker
  mapfile -t RUNNING_NODES < <(get_running_anylog_nodes)

  if [[ ${#RUNNING_NODES[@]} -eq 0 ]]; then
    log "No running AnyLog nodes found matching: ${NODE_LIST[*]} — nothing to uninstall."
    return 0
  fi

  log "Nodes to uninstall: ${RUNNING_NODES[*]}"

  for NODE_TYPE in "${RUNNING_NODES[@]}"; do
    log "Uninstalling node: $NODE_TYPE"

    if $DEMO_MODE; then
      # --- Demo uninstall: remove node stack plus gui, grafana, demo images ---
      case "$NODE_TYPE" in
      anylog-standalone-operator)
        sudo make clean ANYLOG_TYPE="${NODE_TYPE}"
        log "Removing demo containers and images for $NODE_TYPE..."
        sudo docker kill gui-1
        sudo docker rm gui-1
        sudo docker rmi anylogco/remote-gui:beta2
        sudo docker kill grafana
        sudo docker rm grafana
        sudo docker rmi anylogco/oh-grafana:latest
        ;;

      anylog-operator)
        log "Removing demo containers and images for $NODE_TYPE..."
        sudo make clean ANYLOG_TYPE="${NODE_TYPE}"
        ;;

      *)
        log "ERROR: Unknown NODE_TYPE '${NODE_TYPE}' in demo uninstall."
        exit 1
        ;;
      esac

    else
      # --- Standard uninstall: clean only the node stack ---
      case "$NODE_TYPE" in
      anylog-generic | anylog-master | anylog-operator | anylog-query | anylog-publisher | anylog-standalone-operator | anylog-standalone-pusher)
        log "Removing containers and images for $NODE_TYPE..."
        sudo make clean ANYLOG_TYPE="${NODE_TYPE}"
        ;;

      *)
        log "ERROR: Unknown NODE_TYPE '${NODE_TYPE}'."
        exit 1
        ;;
      esac
    fi

    log "Node uninstalled: $NODE_TYPE"
  done

  sudo rm -rf ~/Anylog/node
  log "=== Uninstall complete ==="
}

# ---------------------------------------------------------------------------
# UPDATE — uninstall running nodes, then reinstall all requested nodes
# ---------------------------------------------------------------------------
do_update() {
  log "=== Update started ==="
  do_uninstall
  do_install
  log "=== Update complete ==="
}

# check to see if ENV_FILE exists
log "== Checking .env file =="
if [ ! -f "$ENV_FILE" ]; then
    log "== .env file $ENV_FILE doesn't exist...exiting =="
    echo "Error: $ENV_FILE not found."
    exit 1
fi

# Extract current LICENSE_KEY value
CURRENT_KEY=$(grep '^LICENSE_KEY=' "$ENV_FILE" | cut -d '"' -f2)

# If variable not found
if ! grep -q '^LICENSE_KEY=' "$ENV_FILE"; then
    log "== no environment variable LICENSE_KEY in $ENV_FILE.  Exiting =="
    echo "LICENSE_KEY variable not found in $ENV_FILE"
    exit 1
fi

# If blank → prompt user
if [ -z "$CURRENT_KEY" ]; then
    log "== Adding new license key =="
    echo "LICENSE_KEY is currently blank."
    echo "You can request a new license key at https://www.anylog.network/download"
    read -p "Please enter your new LICENSE_KEY: " NEW_KEY

    # Ensure user entered something
    if [ -z "$NEW_KEY" ]; then
        log "== No new key entered.  Exiting =="
        echo "No key entered. Exiting."
        exit 1
    fi

# Replace LICENSE_KEY="" with new key
sed -i "s|^LICENSE_KEY=\"\"|LICENSE_KEY=\"$NEW_KEY\"|" "$ENV_FILE"

# ---------------------------------------------------------------------------
# Command dispatch
# ---------------------------------------------------------------------------
case "$1" in
  install)   do_install ;;
  uninstall) do_uninstall ;;
  update)    do_update ;;
  start)     do_start ;;
  stop)      do_stop ;;
  *)
    log "ERROR: Expected command [install|uninstall|update|start|stop]"
    usage
  ;;
esac

log "=== ALinstall finished ==="
