# deadhop stack

Everything to run [deadhop](https://deadhop.run), and to develop it, that is not one of its
components:

| Path | What |
| --- | --- |
| `compose.yaml` | Production: the payment service, the offline wallet service, the dashboard, and the optional sweeper. Docker builds each image from its repository on GitHub. |
| `dev/docker-compose.yml` | Development only: a regtest bitcoind, Fulcrum and a private relay on loopback. |
| `scripts/` | The development scripts behind `just up`, `just server` and `just pay`. |

## Run deadhop

```sh
git clone https://github.com/deadhop/stack && cd stack
# write .env next to compose.yaml (see the guide), then:
docker compose up -d --build
```

The guide, with every setting: [Run it with Docker Compose](https://deadhop.run/docs/deploy-compose.html).
Start at [Choose a setup](https://deadhop.run/docs/install.html) if you are new.

## Develop

Requirements: Rust, Node 24, Docker, [`just`](https://github.com/casey/just).

```sh
git clone https://github.com/deadhop/stack && cd stack
just clone       # server/, js/, lnaddr/, wallet/ and relay/ next to these files (gitignored)
just install     # the JavaScript workspace in js/
just up          # regtest bitcoind + Fulcrum + private relay, a funded "miner" and a "merchant" wallet
just server      # builds and runs deadhop on the stack; writes js/dashboard/public/config.json
just dashboard              # http://127.0.0.1:4173
just pay <address> <sats>   # pay a regtest invoice from the miner wallet
just down        # remove the stack and its chain data
```

Each component's own gate runs in its checkout (`just check`), and its end-to-end tests
find this stack through the folder layout: `just e2e`. The scripts read
`.env.local` here on every run (gitignored), for example `DEADHOP_ADMINS=npub1…` or
`DOCKER_CONTEXT=orbstack`. The tutorial: [Try it on your machine](https://deadhop.run/docs/quickstart.html).

The components:
[server](https://github.com/deadhop/server) ·
[js](https://github.com/deadhop/js) ·
[lnaddr](https://github.com/deadhop/lnaddr) ·
[wallet](https://github.com/deadhop/wallet) ·
[relay](https://github.com/deadhop/relay) ·
[site](https://github.com/deadhop/site) ·
[brand](https://github.com/deadhop/brand).

## License

[MIT](LICENSE).
