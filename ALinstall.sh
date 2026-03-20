#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# Cross-platform support: macOS (Darwin) + Linux (apt/yum/dnf/zypper/pacman)
# POSIX /bin/sh version
# ---------------------------------------------------------------------------

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

detect_os() {
  OS=$(uname -s)
  case "$OS" in
    Darwin) OS_TYPE="macos" ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        OS_TYPE="apt"
      elif command -v dnf >/dev/null 2>&1; then
        OS_TYPE="dnf"
      elif command -v yum >/dev/null 2>&1; then
        OS_TYPE="yum"
      elif command -v zypper >/dev/null 2>&1; then
        OS_TYPE="zypper"
      elif command -v pacman >/dev/null 2>&1; then
        OS_TYPE="pacman"
      else
        OS_TYPE="unknown"
      fi
      ;;
    *) OS_TYPE="unknown" ;;
  esac
}
detect_os

sedi() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$1" "$2"
  else
    sed -i '' "$1" "$2"
  fi
}

detect_network() {
  if [ "$OS_TYPE" = "macos" ]; then
    NIC_TYPE=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
    if [ -z "$NIC_TYPE" ]; then
      NIC_TYPE=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
    fi
    IP_ADDR=$(ipconfig getifaddr "$NIC_TYPE" 2>/dev/null)
    if [ -z "$IP_ADDR" ]; then
      IP_ADDR=$(ifconfig "$NIC_TYPE" 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.' | head -n 1)
    fi
  else
    if command -v ip >/dev/null 2>&1; then
      NIC_TYPE=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
      IP_ADDR=$(ip -4 addr show "$NIC_TYPE" 2>/dev/null | awk '/inet /{sub(/\/.*/, "", $2); print $2; exit}')
    else
      NIC_TYPE=$(netstat -rn 2>/dev/null | awk '/^(0\.0\.0\.0|default)/{print $NF; exit}')
      IP_ADDR=$(ifconfig "$NIC_TYPE" 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.' | head -n 1)
    fi
  fi
}

install_packages() {
  case "$OS_TYPE" in
    macos)
      if ! command -v brew >/dev/null 2>&1; then
        printf 'ERROR: Homebrew not found. Install it from https://brew.sh\n' >&2
        exit 1
      fi
      brew install "$@"
      ;;
    apt)    sudo apt-get -y install "$@" ;;
    dnf)    sudo dnf -y install "$@" ;;
    yum)    sudo yum -y install "$@" ;;
    zypper) sudo zypper -n install "$@" ;;
    pacman) sudo pacman -Sy --noconfirm "$@" ;;
    *)
      log "WARNING: Unknown package manager — please install manually: $*"
      ;;
  esac
}

pkg_name() {
  name="$1"
  case "$name" in
    make) echo "make" ;;
    gettext) echo "gettext" ;;
    rsyslog)
      if [ "$OS_TYPE" = "macos" ]; then
        echo ""
      else
        echo "rsyslog"
      fi
      ;;
    docker) echo "" ;;
    *) echo "" ;;
  esac
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed: $(docker --version)"
    return 0
  fi

  log "Installing Docker..."
  case "$OS_TYPE" in
    macos)
      if command -v brew >/dev/null 2>&1; then
        brew install --cask docker
        log "Docker Desktop installed via Homebrew. Please launch Docker Desktop before continuing."
        retries=30
        while :; do
          if docker info >/dev/null 2>&1; then
            break
          fi
          retries=$((retries - 1))
          if [ "$retries" -le 0 ]; then
            break
          fi
          log "Waiting for Docker daemon..."
          sleep 5
        done
      else
        printf 'ERROR: Homebrew required to install Docker on macOS.\n' >&2
        exit 1
      fi
      ;;
    apt)
      sudo apt-get -y install ca-certificates curl gnupg lsb-release
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu %s stable\n' \
        "$(dpkg --print-architecture)" "$(lsb_release -cs)" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      sudo apt-get update
      sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    dnf|yum)
      sudo "$OS_TYPE" -y install dnf-plugins-core >/dev/null 2>&1 || true
      sudo "$OS_TYPE" config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1 || true
      sudo "$OS_TYPE" -y install docker-ce docker-ce-cli containerd.io
      sudo systemctl enable --now docker
      ;;
    zypper)
      sudo zypper -n install docker
      sudo systemctl enable --now docker
      ;;
    pacman)
      sudo pacman -Sy --noconfirm docker
      sudo systemctl enable --now docker
      ;;
    *)
      log "WARNING: Cannot auto-install Docker on this OS. Install manually."
      ;;
  esac
}

enable_syslog() {
  case "$OS_TYPE" in
    macos)
      log "macOS: skipping rsyslog setup (native syslog is always active)"
      ;;
    *)
      if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl enable rsyslog >/dev/null 2>&1 || true
        sudo systemctl start rsyslog >/dev/null 2>&1 || true
      elif command -v service >/dev/null 2>&1; then
        sudo service rsyslog start >/dev/null 2>&1 || true
      else
        log "WARNING: Cannot start rsyslog — no systemctl or service found"
      fi
      ;;
  esac
}

restart_syslog() {
  case "$OS_TYPE" in
    macos)
      log "macOS: skipping rsyslog restart"
      ;;
    *)
      if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl restart rsyslog >/dev/null 2>&1 || true
      elif command -v service >/dev/null 2>&1; then
        sudo service rsyslog restart >/dev/null 2>&1 || true
      fi
      ;;
  esac
}

patch_readme() {
  readme="$AL_DIR/README.html"
  if [ ! -f "$readme" ]; then
    log "README.html not found at $readme — skipping IP patch"
    return 0
  fi
  log "Patching README.html: replacing 'vmipaddr' with ${IP_ADDR}..."
  sedi "s/vmipaddr/${IP_ADDR}/g" "$readme"
  log "README.html patched."
}

configure_rsyslog_forwarding() {
  target_ip="$1"
  target_port="$2"
  case "$OS_TYPE" in
    macos)
      log "macOS: configuring syslog forwarding via /etc/syslog.conf..."
      conf_line="*.* @${target_ip}:${target_port}"
      if ! grep -qF "$conf_line" /etc/syslog.conf 2>/dev/null; then
        printf '%s\n' "$conf_line" | sudo tee -a /etc/syslog.conf >/dev/null
      fi
      sudo launchctl unload /System/Library/LaunchDaemons/com.apple.syslogd.plist >/dev/null 2>&1 || true
      sudo launchctl load /System/Library/LaunchDaemons/com.apple.syslogd.plist >/dev/null 2>&1 || true
      ;;
    *)
      sudo tee /etc/rsyslog.d/60-custom-forwarding.conf >/dev/null <<EOF2
template(name="MyCustomTemplate" type="string" string="<%PRI%>%TIMESTAMP% %HOSTNAME% %syslogtag% %msg%\\n")
*.* action(type="omfwd" target="${target_ip}" port="${target_port}" protocol="tcp" template="MyCustomTemplate")
EOF2
      restart_syslog
      ;;
  esac
}

install_autostart() {
  src="$1"
  case "$OS_TYPE" in
    macos)
      label="com.anylog.$(basename "${src%.desktop}")"
      plist="$HOME/Library/LaunchAgents/${label}.plist"
      exec_line=$(grep '^Exec=' "$src" 2>/dev/null | cut -d= -f2- | head -n 1)
      if [ -n "$exec_line" ]; then
        {
          printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
          printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
          printf '%s\n' '<plist version="1.0">'
          printf '%s\n' '<dict>'
          printf '  <key>Label</key>         <string>%s</string>\n' "$label"
          printf '%s\n' '  <key>ProgramArguments</key>'
          printf '%s\n' '  <array>'
          for arg in $exec_line; do
            printf '    <string>%s</string>\n' "$arg"
          done
          printf '%s\n' '  </array>'
          printf '%s\n' '  <key>RunAtLoad</key>     <true/>'
          printf '%s\n' '</dict>'
          printf '%s\n' '</plist>'
        } > "$plist"
        launchctl unload "$plist" >/dev/null 2>&1 || true
        launchctl load "$plist"
        log "macOS: autostart plist installed at $plist"
      else
        log "WARNING: Could not parse Exec= from $src — skipping autostart"
      fi
      ;;
    *)
      mkdir -p "$HOME/.config/autostart"
      cp "$src" "$HOME/.config/autostart/"
      ;;
  esac
}

docker_cmd() {
  if [ "$OS_TYPE" = "macos" ]; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

make_cmd() {
  if [ "$OS_TYPE" = "macos" ]; then
    make "$@"
  else
    sudo make "$@"
  fi
}

has_docker() {
  command -v docker >/dev/null 2>&1
}

cleanup_anylogco_containers() {
  if ! has_docker; then
    log "Docker not installed — skipping anylogco container cleanup"
    return 0
  fi

  log "Checking for containers using images containing 'anylogco'..."
  docker_cmd ps -a --format '{{.ID}} {{.Image}}' 2>/dev/null | \
  while IFS=' ' read -r cid img; do
    case "$img" in
      *anylogco*)
        log "Removing container $cid ($img)"
        docker_cmd rm -f "$cid" >/dev/null 2>&1 || log "Warning: failed to remove container $cid"
        ;;
    esac
  done

  return 0
}

cleanup_anylogco_images() {
  if ! has_docker; then
    log "Docker not installed — skipping anylogco image cleanup"
    return 0
  fi

  log "Checking for images containing 'anylogco'..."
  docker_cmd images --format '{{.Repository}}:{{.Tag}} {{.ID}}' 2>/dev/null | \
  while IFS=' ' read -r image_name image_id; do
    case "$image_name" in
      *anylogco*)
        log "Removing image $image_name ($image_id)"
        docker_cmd rmi -f "$image_id" >/dev/null 2>&1 || log "Warning: failed to remove image $image_name"
        ;;
    esac
  done

  return 0
}

cleanup_anylogco_compose() {
  if ! has_docker; then
    return 0
  fi

  if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ] || [ -f compose.yml ] || [ -f compose.yaml ]; then
    log "Compose file detected — attempting compose shutdown"
    if docker compose version >/dev/null 2>&1; then
      docker_cmd compose down --remove-orphans >/dev/null 2>&1 || log "Warning: docker compose down failed"
    elif command -v docker-compose >/dev/null 2>&1; then
      if [ "$OS_TYPE" = "macos" ]; then
        docker-compose down --remove-orphans >/dev/null 2>&1 || log "Warning: docker-compose down failed"
      else
        sudo docker-compose down --remove-orphans >/dev/null 2>&1 || log "Warning: docker-compose down failed"
      fi
    fi
  fi

  return 0
}

cleanup_dangling_images() {
  if ! has_docker; then
    return 0
  fi

  log "Removing dangling images..."
  docker_cmd image prune -f >/dev/null 2>&1 || log "Warning: failed to prune dangling images"
  return 0
}

AL_DIR=$(pwd)
ENV_FILE="$AL_DIR/ALinstall.env"
NODE_LIST_ARG=""
AUTO_START=false
AUTO_STOP=false
DEMO_MODE=false

usage() {
  printf 'Usage: %s [-e env_file] [-n node1,node2,...] [-s] [-k] [-d] [install|uninstall|update|start|stop]\n' "$0"
  printf '  -e  Path to environment file (default: ./ALinstall.env)\n'
  printf '  -n  Comma-delimited list of node types to act on\n'
  printf '      Valid nodes: %s\n' "$VALID_NODES"
  printf '  -s  Automatically start nodes after install or update\n'
  printf '  -k  Automatically stop nodes before uninstall or update\n'
  printf '  -d  Demo mode: install/uninstall the full demo environment (overrides -n)\n'
  exit 1
}

while getopts ':e:n:skd' opt; do
  case "$opt" in
    e) ENV_FILE="$OPTARG" ;;
    n) NODE_LIST_ARG="$OPTARG" ;;
    s) AUTO_START=true ;;
    k) AUTO_STOP=true ;;
    d) DEMO_MODE=true ;;
    :) printf 'ERROR: Option -%s requires an argument.\n' "$OPTARG" >&2; usage ;;
    \?) printf 'ERROR: Unknown option -%s.\n' "$OPTARG" >&2; usage ;;
  esac
done
shift $((OPTIND - 1))

ACTION="${1:-}"

if [ "$DEMO_MODE" = true ]; then
  NODE_LIST="$VALID_NODES"
elif [ -n "$NODE_LIST_ARG" ]; then
  NODE_LIST=$(printf '%s' "$NODE_LIST_ARG" | tr ',' ' ')
  for n in $NODE_LIST; do
    valid=false
    for v in $VALID_NODES; do
      if [ "$n" = "$v" ]; then
        valid=true
        break
      fi
    done
    if [ "$valid" != true ]; then
      printf "ERROR: Unknown node type '%s'. Valid nodes: %s\n" "$n" "$VALID_NODES" >&2
      exit 1
    fi
  done
fi

LOG_DIR="$AL_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/ALinstall_${ACTION:-unknown}_$(date '+%Y%m%d_%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

log "=== ALinstall started: OS=${OS_TYPE} command='${ACTION:-unknown}' env='${ENV_FILE}' nodes='${NODE_LIST}' demo=${DEMO_MODE} ==="
log "Log file: ${LOG_FILE}"

ensure_kv() {
  k="$1"
  v="$2"
  f="$3"

  [ ! -f "$f" ] && touch "$f"

  tmp="${f}.tmp"

  # Wrap value in single quotes, escaping any literal single quotes as '\''
  # This is the only quoting style that survives `source` with JSON/special chars
  escaped_v=$(printf '%s' "$v" | sed "s/'/'\\\\''/g")

  grep -v "^${k}=" "$f" > "$tmp"
  printf "%s='%s'\n" "$k" "$escaped_v" >> "$tmp"
  mv "$tmp" "$f"
}


if [ ! -f "$ENV_FILE" ]; then
  log "ERROR: Environment file not found: $ENV_FILE"
  exit 1
fi
set -a
. "$ENV_FILE"
set +a

detect_network
log "Detected OS: ${OS_TYPE}  NIC: ${NIC_TYPE}  IP: ${IP_ADDR}"

if [ -z "$IP_ADDR" ]; then
  log "ERROR: Could not detect IP address. Please set IP_ADDR manually in ${ENV_FILE}."
  exit 1
fi

CURRENT_KEY=$(grep '^LICENSE_KEY=' "$ENV_FILE" | sed "s/^LICENSE_KEY=['\"]//;s/['\"]\$//")

if ! grep -q '^LICENSE_KEY=' "$ENV_FILE"; then
  log "== no environment variable LICENSE_KEY in $ENV_FILE.  Exiting =="
  printf 'LICENSE_KEY variable not found in %s\n' "$ENV_FILE"
  exit 1
fi

if [ -z "$CURRENT_KEY" ]; then
  log "== Adding new license key =="
  printf 'LICENSE_KEY is currently blank.\n'
  printf 'You can request a new license key at https://www.anylog.network/download\n'
  printf 'Please enter your new LICENSE_KEY: '
  read NEW_KEY
  # Normalize smart quotes → regular quotes
# normalize smart quotes safely
  NEW_KEY=$(printf '%s' "$NEW_KEY" | sed 's/[“”]/"/g')

  if [ -z "$NEW_KEY" ]; then
    log "== No new key entered.  Exiting =="
    printf 'No key entered. Exiting.\n'
    exit 1
  fi
else
  NEW_KEY="$CURRENT_KEY"
fi

ensure_kv "LICENSE_KEY" "$NEW_KEY" "$ENV_FILE"

log "== New key inserted =="

apply_env_to_configs() {
  base_cfg="$1"
  skip_keys='TAG|COMPOSE_VER'
  while IFS='=' read -r key value || [ -n "$key" ]; do
    case "$key" in
      ''|'#'*) continue ;;
    esac
    key=$(printf '%s' "$key" | tr -d '[:space:]')
    [ -n "$key" ] || continue
    printf '%s\n' "$key" | grep -Eq "^(${skip_keys})$" && continue
    ensure_kv "$key" "$value" "$base_cfg"
  done < "$ENV_FILE"
}

get_target_nodes() {
  if [ "$DEMO_MODE" = true ]; then
    printf "%s\n" "anylog-standalone-operator anylog-operator grafana"
  else
    printf "%s\n" "$NODE_LIST"
  fi
}

get_running_anylog_nodes() {
  running_containers=$(docker_cmd ps --format '{{.Image}}' 2>/dev/null | grep -E 'anylog-co')

  if [ -z "$running_containers" ]; then
    return 0
  fi

  printf '%s\n' "$running_containers"
}

do_start() {
  cd "$AL_DIR/node/docker-compose" || exit 1
  if [ "$DEMO_MODE" = true ]; then
    for NODE_TYPE in anylog-standalone-operator anylog-operator; do
      log "Starting node: $NODE_TYPE"
      make_cmd up ANYLOG_TYPE="${NODE_TYPE}"
      log "Node started: $NODE_TYPE"
    done

    log "== Starting AnyLog GUI =="
#    docker_cmd run -it -d -p 31800:31800 -p 8080:8080 --restart unless-stopped \
#      -e REACT_APP_API_URL="http://${IP_ADDR}:8080" \
#      --name gui-1 anylogco/remote-gui:beta2

    log "== Starting Grafana =="
    docker_cmd run -it -d -p 3000:3000 --restart unless-stopped \
      -e DATASOURCE_URL="http://${IP_ADDR}:32149" \
      --name grafana anylogco/oh-grafana:latest
  else
    for NODE_TYPE in $NODE_LIST; do
      log "Starting node: $NODE_TYPE"
      make_cmd up ANYLOG_TYPE="${NODE_TYPE}"
      log "Node started: $NODE_TYPE"
    done
  fi
}

do_stop() {
  log "Stopping nodes using make down..."

  if [ -d "$AL_DIR/node/docker-compose" ]; then
    cd "$AL_DIR/node/docker-compose" || exit 1

    for NODE_TYPE in $NODE_LIST; do
      log "Stopping node: $NODE_TYPE"
      make_cmd down ANYLOG_TYPE="$NODE_TYPE"
      log "Node stopped: $NODE_TYPE"
    done
  else
    log "No docker-compose directory found — nothing to stop"
  fi
}} {{.Image}}')

  if [ "$DEMO_MODE" = true ]; then
    docker_cmd kill grafana
    docker_cmd rm -f grafana

  fi
 
  if [ "$AUTO_STOP" = true ]; then
    cleanup_anylogco_containers
    
  fi
}

do_install() {
  set -e

  log "=== Install started (OS=${OS_TYPE} demo=${DEMO_MODE}) ==="
  log "Installing system packages..."
  install_docker

  PKGS=""
  for p in make gettext rsyslog; do
    n=$(pkg_name "$p")
    if [ -n "$n" ]; then
      PKGS="$PKGS $n"
    fi
  done
  if [ -n "$PKGS" ]; then
    # shellcheck disable=SC2086
    install_packages $PKGS
  fi

  log "Cloning docker-compose repo (branch: ${COMPOSE_VER})..."
  mkdir -p "$AL_DIR/node"
  cd "$AL_DIR/node" || exit 1
  if [ -d docker-compose/.git ]; then
    log "docker-compose repo already exists — refreshing it"
    cd docker-compose || exit 1
    git fetch --all
    git checkout "${COMPOSE_VER}"
    git pull --ff-only origin "${COMPOSE_VER}" || true
  else
    git clone -b "${COMPOSE_VER}" https://github.com/anylog-co/docker-compose
    DOCKER_MAKEFILES_DIR="$AL_DIR/node/docker-compose/docker-makefiles"
    if [ -d "$DOCKER_MAKEFILES_DIR" ]; then
      VALID_NODES=$(ls -d "$DOCKER_MAKEFILES_DIR"/*/ 2>/dev/null | xargs -n 1 basename)
      NODE_LIST="$VALID_NODES"
    else
      log "ERROR: Cannot find docker-makefiles directory at $DOCKER_MAKEFILES_DIR"
      exit 1
    fi
    cd docker-compose || exit 1
  fi
  docker_cmd login -u anyloguser -p dckr_pat_tWYofE1Jx68FXXE9kisQONXE2Sw

  log "Setting Makefile TAG to ${TAG}..."
  sedi "s/^export TAG ?= .*/export TAG ?= ${TAG}/" Makefile

  h=$(hostname)

  if [ "$DEMO_MODE" = true ]; then
    log "Enabling syslog..."
    enable_syslog

    log "Installing autostart entry..."
    if [ -f "$AL_DIR/startup-readme.desktop" ]; then
      install_autostart "$AL_DIR/startup-readme.desktop"
    fi

    log "Configuring syslog forwarding to ${IP_ADDR}:32160..."
    configure_rsyslog_forwarding "${IP_ADDR}" "32160"

    for NODE_TYPE in anylog-standalone-operator anylog-operator; do
      log "Configuring node: $NODE_TYPE"
      NENV="docker-makefiles/${NODE_TYPE}/node_configs.env"
      log "Cleaning node: $NODE_TYPE"
      make_cmd up ANYLOG_TYPE="$NODE_TYPE"
      log "Node configured: $NODE_TYPE"
    done
  else
    for NODE_TYPE in $NODE_LIST; do
      NENV="docker-makefiles/${NODE_TYPE}/node_configs.env"
      log "Cleaning node: $NODE_TYPE"
      make_cmd up ANYLOG_TYPE="$NODE_TYPE"
      log "Node configured: $NODE_TYPE"
    done
  fi

  if [ "$AUTO_START" = true ]; then
    log "=== Auto-start: launching nodes ==="
    do_start
  else
    log "Install complete. Run '$0 [-n nodes] start' or re-run with -s to start nodes."
  fi

  log "Patching README.html with VM IP address..."
  patch_readme

  log "=== Install complete ==="
}

do_uninstall() {
  log "=== Uninstall running nodes (demo=${DEMO_MODE}) ==="

  if [ -d "$AL_DIR/node/docker-compose" ]; then
    cd "$AL_DIR/node/docker-compose" || exit 1
  fi

  if [ "$AUTO_STOP" = true ]; then
    log "-k specified: stopping matching nodes before uninstall"
    do_stop
    if [ -d "$AL_DIR/node/docker-compose" ]; then
      cd "$AL_DIR/node/docker-compose" || exit 1
    fi
  fi

  RUNNING_NODES=$(get_running_anylog_nodes)
  if [ -z "$RUNNING_NODES" ]; then
    log "No running AnyLog nodes found matching: ${NODE_LIST} — nothing to uninstall via make clean."
  else
    log "Nodes to uninstall: $(printf '%s ' $RUNNING_NODES)"
    printf '%s\n' "$RUNNING_NODES" | while IFS= read -r NODE_TYPE; do
      [ -n "$NODE_TYPE" ] || continue
      log "Uninstalling node: $NODE_TYPE"
      log "Cleaning node: $NODE_TYPE"
      make_cmd clean ANYLOG_TYPE="$NODE_TYPE"
      log "Node uninstalled: $NODE_TYPE"
    done
  fi

  cleanup_anylogco_compose
  cleanup_anylogco_containers
  cleanup_anylogco_images
  cleanup_dangling_images

  sudo rm -rf "$AL_DIR/node"
  log "=== Uninstall complete ==="
}

do_update() {
  log "=== Update started ==="
  if [ "$AUTO_STOP" = true ]; then
    log "-k specified: stopping nodes before update"
  fi
  do_uninstall
  do_install
  log "=== Update complete ==="
}

case "$ACTION" in
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
