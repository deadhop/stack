---
name: deadhop-stack-deploy
description: "Deploy and run deadhop in production with Docker Compose from deadhop/stack: the offline wallet, the payment service, the dashboard and the optional sweeper. Use it whenever someone wants to install, deploy, self-host, start, update or back up deadhop on a server or node box with Docker, write its .env, generate a wallet and save the recovery phrase, check the first receive address, put the dashboard behind a reverse proxy (Caddy, Traefik, nginx), turn on sweeping to a cold wallet, or when `docker compose up` fails or a container is unhealthy."
license: MIT
metadata:
  repository: https://github.com/deadhop/stack
---

# Deploy deadhop with Docker Compose

`compose.yaml` in this repository runs deadhop next to the operator's bitcoin node. Docker
builds each image from its repository's `main` branch on GitHub (deadhop/server, deadhop/js,
deadhop/wallet), so this file is all a deployment needs.

| Container | What it does | Network |
| --- | --- | --- |
| `wallet` | Generates a wallet on first start, keeps its recovery phrase, hands only the account public key to the service. Idle with your own `DEADHOP_XPUB` | none at all |
| `deadhop` | The payment service, watch-only | outbound only: relays and the Electrum server |
| `dashboard` | The dashboard as static files on port 8080 inside Docker | serves HTTP, publishes no port |
| `sweeper` | Optional (`sweep` profile): moves the balance to a cold wallet | outbound only |

The full guide is [deploy-compose.md](https://deadhop.run/docs/deploy-compose.md). Every docs
page has a Markdown twin at `https://deadhop.run/docs/<page>.md`; fetch it for details.

## Safety rules

- **The recovery phrase belongs to the user, on paper.** Never run
  `deadhop wallet export` yourself, never ask for the words, and never let them reach the
  chat, a file, a log or an issue: whoever has them can spend the funds. Give the user the
  command to run in their own terminal.
- **Never `docker compose down -v`, and never rename the volume keys** in `compose.yaml`. The
  volumes hold the wallet's phrase, the service's keys and the database. They keep the old
  project name `cvmpay-…` on purpose: a renamed volume starts the service with an empty one, a
  new service key and a new wallet.
- **Never publish the dashboard port on all interfaces**: bind it to `127.0.0.1` and put a TLS
  reverse proxy in front. Do not forward a port from a home router to it: that puts the home
  address on every payment link.
- **Public keys only in `.env`.** `DEADHOP_ADMINS` takes `npub1…` (or hex); the operator signs
  in with a NIP-07 browser extension. Never ask for an `nsec`.
- **Goods ship on `confirmed`, never `detected`.** A shop's backend checks each invoice with
  `getInvoice(id)` itself ([integrate-backend.md](https://deadhop.run/docs/integrate-backend.md)).

## Decide with the user first

1. **Their Electrum server** (Fulcrum or electrs on their node): its LAN address and whether it
   has a TLS port. See [electrum.md](https://deadhop.run/docs/electrum.md).
2. **Wallet:** their own wallet's BIP-84 account key (`zpub6…`, [xpub/index.md](https://deadhop.run/docs/xpub/index.md)),
   or a generated one (small balances; optionally swept). This cannot change once addresses
   have been handed out.
3. **Hidden or not:** if relays must not learn the server's IP address, set up Tor
   ([hide.md](https://deadhop.run/docs/hide.md), a Tor container in `compose.override.yaml`)
   **before the first start**.
4. Other combinations: [setups.md](https://deadhop.run/docs/setups.md).

Requirements: Docker with Compose v2, and an Electrum server the host can reach.

## 1. Get the file and write `.env`

```sh
git clone https://github.com/deadhop/stack && cd stack
```

`.env` next to `compose.yaml` (gitignored):

```sh
DEADHOP_ELECTRUM=tls://node.lan:50002          # or host:port plain TCP on a trusted network (warns)
DEADHOP_ELECTRUM_CERT_SHA256=<fingerprint>
DEADHOP_ADMINS=npub1…                          # the operator's sign-in key
# DEADHOP_XPUB=zpub6…                          # own wallet; leave out to generate one
# DEADHOP_RELAYS=wss://…,wss://…               # default: relay.contextvm.org, nos.lol, relay.damus.io
# DEADHOP_NAME=Corner Bakery
```

Read the fingerprint with `docker compose run --rm --no-deps deadhop fingerprint node.lan:50002`
and have the user compare it on the node
(`openssl x509 -in <fulcrum cert.pem> -noout -fingerprint -sha256`): the command trusts
whatever answered. Inside a container `127.0.0.1` is the container; use the host's LAN address.
Any setting in [configuration.md](https://deadhop.run/docs/configuration.md) can go here.

## 2. First start

```sh
docker compose up -d --build
docker compose ps
docker compose logs deadhop | grep -E "serving|first receive address"
```

The first build takes several minutes. `wallet`, `deadhop` and `dashboard` should report
`healthy` (the service becomes healthy once it has connected to its relays). Expect:

```text
INFO deadhop::app: deadhop is serving pubkey=… network=bitcoin relays=3 via_proxy=false paused=false
INFO deadhop::app: first receive address (index 0): check that your wallet lists it address=bc1q…
```

## 3. Recovery phrase (generated wallet only)

Tell the user to run this themselves, in their own terminal, and write the 24 words on paper:

```sh
docker compose exec wallet deadhop wallet export
```

Do not run it for them. The dashboard warns until the words have been exported. With their own
`DEADHOP_XPUB` the command is refused: the phrase is in their wallet.

## 4. Check the first address

The user watches the account key (the export prints it; with their own wallet, their wallet
itself), for example in Sparrow as an xPub / Watch Only wallet. Its first receive address must
equal the logged one. If it does not, stop before any payment: the money would go where their
wallet cannot see it. Then raise the wallet's gap limit to the dashboard's **addresses
created** plus 20.

## 5. Dashboard behind a reverse proxy

A proxy on the same Docker network points at `dashboard:8080`. Otherwise publish on loopback
with `compose.override.yaml` (Compose reads it on its own), then `docker compose up -d`:

```yaml
services:
  dashboard:
    ports:
      - "127.0.0.1:8080:8080"
```

Put TLS in front with these headers (Caddy example in [dashboard.md](https://deadhop.run/docs/dashboard.md)):
`Content-Security-Policy: frame-ancestors 'none'`, `X-Content-Type-Options: nosniff`,
`Referrer-Policy: no-referrer`. The user signs in with **Use browser extension**; a key in
`DEADHOP_ADMINS` gets the operator view. `DEADHOP_DASHBOARD_RELAYS` and
`DEADHOP_DASHBOARD_ADMIN_RELAYS` override the relays the page uses.

## 6. Sweeper (optional, generated wallet)

Add to `.env`, leaving `DEADHOP_XPUB` unset:

```sh
DEADHOP_WALLET_DESTINATION=zpub6…        # a different, cold wallet's account key
DEADHOP_WALLET_THRESHOLD_SAT=2000000
DEADHOP_WALLET_MAX_FEE_RATE=20
```

```sh
docker compose --profile sweep up -d --build
docker compose --profile sweep logs sweeper
docker compose --profile sweep exec sweeper deadhop-wallet status
```

Have the user check the destination key's first address in their cold wallet first. Modes
(send, PayJoin, CoinJoin): [wallet/sweep.md](https://deadhop.run/docs/wallet/sweep.md),
[wallet/configuration.md](https://deadhop.run/docs/wallet/configuration.md).

## Updating

```sh
git pull
docker compose up -d --build              # add --profile sweep if the sweeper runs
```

State lives in the named volumes and survives rebuilds. Back up the service's data volume
(`cvmpay-data`, mounted at `/data`) with its permissions intact, and copy its `backups/` off
the host regularly. The generated wallet's backup is the words on paper: do not copy the
`cvmpay-wallet` volume anywhere, it holds the phrase.

## Before real payments

Walk the [production checklist](https://deadhop.run/docs/deployment.md) with the user.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `deadhop` keeps restarting with "DEADHOP_ELECTRUM is required" or "set DEADHOP_ADMINS and/or DEADHOP_PUBLIC_INVOICING=true" | Set it in `.env` |
| "server is on a different chain" | `DEADHOP_NETWORK` (default `bitcoin`) does not match the Electrum server |
| Certificate refused | Re-read the fingerprint and compare it on the node |
| Cannot reach Electrum at `127.0.0.1` | That is the container; use the host's LAN address |
| `deadhop` not healthy after two minutes | No relay connected: check `DEADHOP_RELAYS`, the proxy, or `kill_switch` while Tor starts |
| "this database was used with a different wallet key" | `DEADHOP_XPUB` changed after addresses were handed out; switch back |
| Dashboard unreachable | It publishes no port: add the loopback override or join the proxy's network |
| Sweeper "holding: no destination is set" | Set `DEADHOP_WALLET_DESTINATION` |

`docker compose logs <service>` shows each container's messages.
