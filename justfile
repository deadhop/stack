# deadhop stack: production compose file, regtest development stack, dev scripts.
# Run `just` to list the tasks.
default:
    @just --list

# Clone the components next to these files, to develop and test without the workspace
clone:
    for r in server js lnaddr wallet relay; do [ -d "$r" ] || git clone "https://github.com/deadhop/$r.git" "$r"; done

# Start the isolated regtest stack (bitcoind, Fulcrum, private relay) and its two wallets
up:
    scripts/dev-up.sh

# Stop the regtest stack and delete its chain data
down:
    docker compose -f dev/docker-compose.yml down -v

# Build and run the payment service against the regtest stack (needs server/ and js/)
server:
    scripts/dev-server.sh

# Pay a regtest invoice: just pay <address> <sats> [blocks]
pay address sats blocks="1":
    scripts/dev-pay.sh {{address}} {{sats}} {{blocks}}

# Both compose files are valid; the scripts pass shellcheck
check:
    docker compose -f compose.yaml config -q
    docker compose -f dev/docker-compose.yml config -q
    shellcheck -x scripts/*.sh
