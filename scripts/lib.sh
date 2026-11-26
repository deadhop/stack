# The variables are for the scripts that source this file.
# shellcheck shell=bash disable=SC2034
# Shared helpers for the local regtest development stack.
# Everything these scripts create is private to the current user.
umask 077
STACK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# ROOT is the folder that holds the components (server/, js/), data/dev and
# .env.local: the deadhop workspace when this stack is its stack/ submodule,
# otherwise this folder (where `just clone` puts them). DEADHOP_WORKSPACE wins.
if [ -n "${DEADHOP_WORKSPACE:-}" ]; then
  ROOT="$(cd "$DEADHOP_WORKSPACE" && pwd)"
elif [ -f "$STACK/../.gitmodules" ] && [ -d "$STACK/../server" ]; then
  ROOT="$(cd "$STACK/.." && pwd)"
else
  ROOT="$STACK"
fi
COMPOSE="$STACK/dev/docker-compose.yml"
DEV_DIR="$ROOT/data/dev"
RELAY_URL="ws://127.0.0.1:7777"
ELECTRUM_ADDR="127.0.0.1:50001"

# Your local settings (gitignored), read on every run: for example
#   DEADHOP_ADMINS=npub1...        your operator key(s), comma-separated
#   DOCKER_CONTEXT=orbstack       which Docker engine runs the stack
if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi

bcli() {
  docker compose -f "$COMPOSE" exec -T bitcoind \
    bitcoin-cli -regtest -rpcuser=deadhop -rpcpassword=deadhop-dev-only "$@"
}
