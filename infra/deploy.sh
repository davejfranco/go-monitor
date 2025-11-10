#!/usr/bin/env bash

set -euo pipefail

# App
SRC="../"
APP_NAME="go-monitor"
REMOTE_GOOS="linux"
REMOTE_GOARCH="amd64"

# Server configuration
HUB_ROUTER_IP=$(terraform output -raw hub_router_public_ip)
SPOKE_1_ROUTER_IP=$(terraform output -raw spoke_1_router_public_ip)
SPOKE_2_ROUTER_IP=$(terraform output -raw spoke_2_router_public_ip)
CONFIG_PATH="config"
DEPLOY_TEMP_DIR=".deploy"
WIREGUARD_KEY_PATH="$DEPLOY_TEMP_DIR/keys"
WIREGUARD_CONFIG_PATH="$DEPLOY_TEMP_DIR/config"
SSH_KEY="bird-key.pem"

declare -A ROUTERS
ROUTERS["hub"]="$HUB_ROUTER_IP"
ROUTERS["spoke-1"]="$SPOKE_1_ROUTER_IP"
ROUTERS["spoke-2"]="$SPOKE_2_ROUTER_IP"

if [[ ! -d $DEPLOY_TEMP_DIR ]]; then
  mkdir $DEPLOY_TEMP_DIR
fi

wireguard_keys() {
  local server=$1
  if [[ ! -d $WIREGUARD_KEY_PATH ]] || [[ ! -d "$WIREGUARD_KEY_PATH/$server" ]]; then
    mkdir -p "$WIREGUARD_KEY_PATH/$server"
  fi

  umask 077
  wg genkey | tee "$WIREGUARD_KEY_PATH/$server/privatekey" | wg pubkey >"$WIREGUARD_KEY_PATH/$server/publickey"
}

generate_wg_config() {

  if [[ ! -d $WIREGUARD_KEY_PATH ]]; then
    echo "wireguard keys probably missing..."
    exit 1
  fi

  mkdir -p $WIREGUARD_CONFIG_PATH

  echo "generating hub router config..."
  HUB_PRIVATE_KEY=$(cat "$WIREGUARD_KEY_PATH/hub/privatekey")
  HUB_PUBLIC_KEY=$(cat "$WIREGUARD_KEY_PATH/hub/publickey")
  SPOKE_1_PRIVATE_KEY=$(cat "$WIREGUARD_KEY_PATH/spoke-1/privatekey")
  SPOKE_1_PUBLIC_KEY=$(cat "$WIREGUARD_KEY_PATH/spoke-1/publickey")
  SPOKE_2_PRIVATE_KEY=$(cat "$WIREGUARD_KEY_PATH/spoke-2/privatekey")
  SPOKE_2_PUBLIC_KEY=$(cat "$WIREGUARD_KEY_PATH/spoke-2/publickey")

  sed -e "s|HUB_ROUTER_PRIVATE_KEY|$HUB_PRIVATE_KEY|g" \
    -e "s|SPOKE_1_ROUTER_PUBLIC_KEY|$SPOKE_1_PUBLIC_KEY|g" \
    -e "s|SPOKE_2_ROUTER_PUBLIC_KEY|$SPOKE_2_PUBLIC_KEY|g" \
    -e "s|SPOKE_1_ROUTER|$SPOKE_1_ROUTER_IP|g" \
    -e "s|SPOKE_2_ROUTER|$SPOKE_2_ROUTER_IP|g" \
    "$CONFIG_PATH/wireguard/hub-wg0.conf" >"$WIREGUARD_CONFIG_PATH/hub-wg0.conf"

  echo "generating spoke-1 router config"
  sed -e "s|SPOKE_1_ROUTER_PRIVATE_KEY|$SPOKE_1_PRIVATE_KEY|g" \
    -e "s|HUB_ROUTER_PUBLIC_KEY|$HUB_PUBLIC_KEY|g" \
    -e "s|HUB_ROUTER|$HUB_ROUTER_IP|g" \
    "$CONFIG_PATH/wireguard/spoke-1-wg0.conf" >"$WIREGUARD_CONFIG_PATH/spoke-1-wg0.conf"

  echo "generating spoke-2 router config"
  sed -e "s|SPOKE_2_ROUTER_PRIVATE_KEY|$SPOKE_2_PRIVATE_KEY|g" \
    -e "s|HUB_ROUTER_PUBLIC_KEY|$HUB_PUBLIC_KEY|g" \
    -e "s|HUB_ROUTER|$HUB_ROUTER_IP|g" \
    "$CONFIG_PATH/wireguard/spoke-2-wg0.conf" >"$WIREGUARD_CONFIG_PATH/spoke-2-wg0.conf"
}

copy_to_remote() {
  local server=$1
  shift

  if [[ $# -eq 0 ]]; then
    echo "Error: No files specified to copy"
    return 1
  fi
  echo "Copying files to $server:/tmp"
  scp -i $SSH_KEY \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$@" admin@$server:/tmp
}

setup_remote() {
  local server=$1
  local server_name=$2

  ssh -i $SSH_KEY \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    admin@$server <<EOF
    set -e 

    sudo sysctl -w net.ipv4.ping_group_range="0 2147483647"

    sudo cp /tmp/nftables.conf /etc/nftable.conf
    sudo systemctl restart nftables

    sudo cp /tmp/$server_name-wg0.conf /etc/wireguard/wg0.conf
    sudo systemctl enable wg-quick@wg0
    sudo systemctl start wg-quick@wg0

    sudo cp /tmp/bird-$server_name.conf /etc/bird/bird.conf
    sudo systemctl restart bird
EOF
}

config() {
  for server in "${!ROUTERS[@]}"; do
    echo "Deploying to $server"
    echo "Copying configuration files to servers..."
    copy_to_remote "${ROUTERS[$server]}" "$CONFIG_PATH/nftables.conf" "$CONFIG_PATH/bird/bird-$server.conf" "$WIREGUARD_CONFIG_PATH/$server-wg0.conf"

    echo "Setting up remote servers..."
    echo "$server..."
    setup_remote "${ROUTERS[$server]}" "$server"
  done
}

generate_config() {
  for server in hub spoke-1 spoke-2; do
    wireguard_keys $server
  done

  generate_wg_config
}

app_build() {
  if [[ ! -d $DEPLOY_TEMP_DIR ]]; then
    echo "Temporary deploy directory does not exist"
    return
  fi

  GOOS=$REMOTE_GOOS GOARCH=$REMOTE_GOARCH go build -o $DEPLOY_TEMP_DIR/go-monitor ../main.go
}

app_deploy() {
  if [[ ! -f $DEPLOY_TEMP_DIR/go-monitor ]]; then
    echo "Binary needs to be build first"
    return
  fi

  copy_to_remote "${ROUTERS[hub]}" $DEPLOY_TEMP_DIR/go-monitor

  ssh -i $SSH_KEY \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    admin@${ROUTERS[hub]} <<EOF
    set -e 

    sudo sysctl -w net.ipv4.ping_group_range="0 2147483647"
    sudo cp /tmp/go-monitor /usr/local/bin
EOF

}

clean() {
  read -p "Are you sure you want to remove deployment files? [Y/N]: " answer
  if [[ "${answer,,}" =~ ^(y|yes)$ ]]; then
    echo "Removing $DEPLOY_TEMP_DIR..."
    rm -rf $DEPLOY_TEMP_DIR
    echo "Done..."
  else
    echo "Cancelled."
    exit 0
  fi
}

help() {
  cat <<EOF
Go monitor deployment script

Usage:
  $0 generate    Generate WireGuard keys and configuration files
  $0 configure   Configure remote servers
  $0 build       Build app
  $0 deploy      Deploy app
  $0 clean       Remove all deployment files
  $0 help        Display this help message
EOF
}

case $1 in
clean)
  echo -n "cleaning deployment files..."
  clean
  ;;
generate)
  echo "generating deployment files..."
  generate_config
  ;;
build)
  echo "Build go-monitor"
  app_build
  ;;
deploy)
  echo "Deploy go-monitor"
  app_deploy
  ;;
config)
  echo "Configuring servers"
  config
  ;;
help)
  help
  ;;
*)
  echo -n "unknown command"
  help
  ;;
esac
