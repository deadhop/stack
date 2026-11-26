---
name: deadhop-stack-regtest
description: "Run the deadhop development stack on a local regtest chain from deadhop/stack: bitcoind, Fulcrum and a private relay on loopback, the payment service built from source, the dashboard, test payments and the end-to-end suite. Use it whenever someone wants to try deadhop locally, develop or debug deadhop/server or deadhop/js against a running service, pay a test invoice, run `just up`, `just server`, `just dashboard`, `just pay` or `just e2e`, build an app against a local deadhop, or when the regtest stack, Fulcrum, the dashboard's config.json or the e2e tests misbehave. Development only, never production."
license: MIT
metadata:
  repository: https://github.com/deadhop/stack
---

# The regtest development stack

A throwaway regtest chain on loopback: bitcoind, Fulcrum (Electrum) and a private Nostr
relay in Docker (`dev/docker-compose.yml`), the payment service built from source by
`just server`, and the dashboard served locally. Nothing touches real bitcoin. The tutorial
version is [quickstart.md](https://deadhop.run/docs/quickstart.md).

## Development only

Never adapt `dev/docker-compose.yml` or these scripts for production: the bitcoind RPC
password is fixed (`deadhop-dev-only`), the wallets are hot, the relay has no
authentication, the Fulcrum and relay images are unpinned, and the service runs with public
invoicing on and weak proof of work. For real payments, use `compose.yaml` (the
deadhop-stack-deploy skill). Everything binds to `127.0.0.1` only; keep it that way.

## Requirements

Docker with Compose v2, [`just`](https://github.com/casey/just), Rust, Node, and `nc` (the
scripts wait on the Electrum port with it). Versions: see the README of each component.

## Get the components

```sh
git clone https://github.com/deadhop/stack && cd stack
just clone       # server/, js/, lnaddr/, wallet/ and relay/ next to these files (gitignored)
just install     # once: npm ci in js/ (just server needs it to make the dev operator key)
```

`just clone` skips a directory that already exists, so it never overwrites work in a
component. To test local changes, edit inside `server/` or `js/` and rerun the step below.

## Local settings: `.env.local`

The scripts read `.env.local` in the stack directory (gitignored) on every run:

```sh
DEADHOP_ADMINS=npub1…        # your own operator key(s), added to the dev key; hex, npub or nprofile
DOCKER_CONTEXT=orbstack      # which Docker engine runs the stack, if not the default
```

Never put secrets or real hosts in a file you commit.

## Run it

Three terminals, in the stack checkout:

```sh
just up          # starts bitcoind, Fulcrum, the relay; a funded "miner" and a "merchant" wallet
```

```sh
just server      # builds server/ in release mode and runs it in the foreground
```

Wait for `deadhop is serving` in that terminal; only then has it written
`js/dashboard/public/config.json` (the service's keys and the relay `ws://127.0.0.1:7777`).
The first build takes a few minutes.

```sh
just dashboard   # builds the dashboard and serves it at http://127.0.0.1:4173
```

What `just server` sets: regtest network, the merchant wallet's BIP-84 account key as
`DEADHOP_XPUB`, Electrum `127.0.0.1:50001`, the relay, public invoicing on, `DEADHOP_POW_BITS`
16 and `DEADHOP_POLL_SECS` 2 (both overridable from the environment), and operators = the dev
key plus `DEADHOP_ADMINS`. Its data goes to `data/dev/server/`.

## Pay an invoice

1. Open http://127.0.0.1:4173, **Continue as guest**, enter an amount, **Create invoice**.
2. Pay it from the miner wallet; this mines one block by default:

   ```sh
   just pay <address> <sats>          # or: just pay <address> <sats> 0   (no block: stays detected)
   ```

3. The page moves to *Payment seen*, then *Paid*.
4. Operator view: the user adds their npub to `.env.local` and restarts `just server`, or
   signs in with the dev key in `data/dev/operator.nsec` (created on first `just server`).
   That file is a dev secret: let the user open it; do not print it into chat.

## End-to-end tests

With `just up` and `just server` running:

```sh
just e2e         # in js/: the console, the dashboard, the built client and every framework's components, in Chrome
```

Server tests that need no stack run in the component: `cd server && just check`.

## Stop and reset

```sh
just down        # stops the stack and deletes its chain data (docker compose down -v on the dev stack)
```

Stop `just server` and `just dashboard` with Ctrl-C. `data/dev/` (the service's database,
keys, the merchant key file and the dev operator key) and `js/dashboard/public/config.json`
stay. A new chain from `just down` + `just up` makes a new merchant wallet; ask before moving
`data/dev/` aside to start the service fresh, and never delete it without asking.

## Check the repository itself

```sh
just check       # both compose files validate, the scripts pass shellcheck (CI runs the same)
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `just server`: "run scripts/dev-up.sh first" | Run `just up`; it writes `data/dev/xpub` |
| `just server` fails at the dev key (`nostr-tools` missing) | Run `just install` first |
| "could not read the merchant wallet's BIP-84 account key" | bitcoind not ready or wallet missing; rerun `just up`, check `docker compose -f dev/docker-compose.yml logs bitcoind` |
| Dashboard says `config.json` is missing | Start it after `deadhop is serving`; stop and rerun `just dashboard` |
| Port 18443, 50001, 7777 or 4173 in use | Another stack or process holds it; stop it, or `just down` |
| The service refuses another wallet key after a chain reset | `data/dev/server/` belongs to the old merchant wallet; move it aside (ask first) |
| Docker commands hit the wrong engine | Set `DOCKER_CONTEXT` in `.env.local` |
| Paid with `0` blocks, invoice stays at *Payment seen* | Mine a block (below); do not pay again |

Mine a block by hand (the same RPC call the scripts make; export `DOCKER_CONTEXT` first if
you set it in `.env.local`):

```sh
bcli() { docker compose -f dev/docker-compose.yml exec -T bitcoind \
  bitcoin-cli -regtest -rpcuser=deadhop -rpcpassword=deadhop-dev-only "$@"; }
bcli generatetoaddress 1 "$(bcli -rpcwallet=miner getnewaddress)"
```

To build an app against this stack: [integrate.md](https://deadhop.run/docs/integrate.md)
(section "Develop against a local service").
