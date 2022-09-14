# Docker Wireguard

Appreciate the work of the good folks at linuxserver/docker-wireguard, but I needed more functionality and other existing projects did not meet the criteria.

This project supports Wireguard in a site-to-site configuration.

## Usage

I built this to be used with `docker-compose`.

See the examples in the `examples` directory.

- Use the `docker-compose.local.yml` file to add (shared) general local dependencies/modifications like custom dns servers for the containers.
- Copy the `docker-compose.wg0.yml` and `wgtest.env` and customize them to fit your use.

### Manually

Use `start`, `stop`, or `restart` to control the container.

Notes:

- The scripts do routing magic.
- You need to be root for this.

### systemd

Copy and adjust the `docker-wireguard.service` file to `/etc/systemd/system/`, adjust the paths in the file, run the command `systemctl enable docker-wireguard` to enable the service, and then run `systemctl start docker-wireguard`.

## Variables

### Wireguard

| Variable  | Usage |
|---|---|
| SERVER_PORT | Wireguard port |
| LOCAL_IPS | Wireguard tunnel addresses |
| LOCAL_SUBNETS | Inside subnets |
| REMOTE_SUBNETS | Remote subnets (specify the tunnel subnet here) |

### Peers

| Variable  | Usage |
|---|---|
| PEER_*X*_ADDRESS | Peer outside address |
| PEER_*X*_RESOLVE | Resolve peer through DNS |
| PEER_*X*_PUBKEY | Public key |
| PEER_*X*_PSK | Pre-shared key|
| PEER_*X*_SUBNETS | Peer specific remote subnets |
| PEER_*X*_KEEPALIVE | Keep alive interval |
