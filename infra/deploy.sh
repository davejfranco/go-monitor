#!/usr/bin/env bash

set -euo pipefail

HUB_ROUTER_IP=$(terraform output -raw hub_router_public_ip)
SPOKE_1_ROUTER_IP=$(terraform output -raw spoke_1_router_public_ip)
SPOKE_2_ROUTER_IP=$(terraform output -raw spoke_2_router_public_ip)
CONFIG_PATH="config"
DEPLOY_TEMP_DIR=".deploy"
WIREGUARD_KEY_PATH="$DEPLOY_TEMP_DIR/keys"
WIREGUARD_CONFIG_PATH="$DEPLOY_TEMP_DIR/config"

if [[ ! -d $DEPLOY_TEMP_DIR ]]; then
  mkdir $DEPLOY_TEMP_DIR
fi

clean() {
  rm -rf $DEPLOY_TEMP_DIR
}

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

generate_config() {
  for server in hub spoke-1 spoke-2; do
    wireguard_keys $server
  done

  generate_wg_config
}

case $1 in

clean)
  echo -n "cleaning deployment files..."
  clean
  ;;
generate)
  echo -n "generating deployment files..."
  generate_config
  ;;
*)
  echo -n "unknown command"
  ;;
esac
