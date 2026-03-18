#!/usr/bin/env bash
set -euo pipefail

HOST=${1:?Usage: bootstrap.sh <hostname>}
FLAKE=${2:-github:EllieBytes/nixos}

echo "Bootstrapping ${HOST} from ${FLAKE}"

sudo nix run github:nix-community/disko -- \
  --mode disko \
  --flake "$FLAKE#$HOST"

if [ $? -ne 0 ]; then
  echo "disko failed with code $?"
  exit $?
fi

sudo nixos-install 
  --flake "$FLAKE#$HOST" \
  --no-root-passwd

if [ $? -ne 0 ]; then
  echo "nixos-install failed with code $?"
  exit $?
fi 

echo "Done! ready to reboot."
