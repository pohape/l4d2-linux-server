[🇷🇺 Russian guide is available here](README.ru.md)

# l4d2-linux-server

Practical templates and setup notes for running a public `Left 4 Dead 2` dedicated server on `Ubuntu 22.04` with:

- native Linux server binaries
- `systemd` service management
- `Metamod:Source`
- `SourceMod` admin access
- custom maps
- `Tank Challenge v1.5` as a verified example

This repository is based on a real deployment on a public VPS, not only on old forum guides.

## Verified setup

- OS: `Ubuntu 22.04`
- Architecture: `x86_64`
- Server install path: `/home/steam/l4d2`
- `SteamCMD` path: `/home/steam/steamcmd`
- Public game port: `27015`
- L4D2 dedicated server app id: `222860`

## Important notes

### Native Linux server

The L4D2 dedicated server runs natively on Linux via `srcds_linux`.

### The server install required a real Steam account with owned L4D2

In this deployment, `anonymous` login did not produce a working Linux install for `app_update 222860`.

What worked:

1. Log into `SteamCMD` with a normal Steam account.
2. That account must own `Left 4 Dead 2`.
3. Run `app_update 222860 validate`.

### The server is still a 32-bit workload

On `Ubuntu 22.04`, install the `i386` runtime packages before downloading the game.

## Repository layout

```text
.
├── README.md
├── README.ru.md
├── docs/
│   └── tank-challenge.md
└── templates/
    ├── server.cfg
    ├── sourcemod/
    │   ├── adminmenu_maplist.ini
    │   └── admins_simple.ini
    └── systemd/
        └── l4d2.service
```

## Quick start

### 1. Install system packages

```bash
sudo adduser --disabled-password --gecos "" steam
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y \
  ca-certificates \
  curl \
  git \
  wget \
  tar \
  tmux \
  screen \
  unzip \
  jq \
  lib32gcc-s1 \
  lib32stdc++6 \
  libc6-i386
```

### 2. Clone this repository

```bash
sudo mkdir -p /opt
sudo git clone https://github.com/pohape/l4d2-linux-server /opt/l4d2-linux-server
sudo chown -R "$USER":"$USER" /opt/l4d2-linux-server
```

If you cloned the repo somewhere else, adjust the paths in the next steps.

### 3. Install SteamCMD manually

```bash
sudo -u steam -H bash -lc '
mkdir -p /home/steam/steamcmd
cd /home/steam/steamcmd
wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
tar -xzf steamcmd_linux.tar.gz
mkdir -p /home/steam/.steam/sdk32
ln -sf /home/steam/steamcmd/linux32/steamclient.so /home/steam/.steam/sdk32/steamclient.so
'
```

### 4. Install the L4D2 dedicated server

```bash
sudo -u steam -H bash -lc 'cd /home/steam/steamcmd && ./steamcmd.sh'
```

Inside the SteamCMD console:

```txt
force_install_dir /home/steam/l4d2
login <steam_login>
app_update 222860 validate
quit
```

Notes:

- `login <steam_login>` is a placeholder; enter your real Steam login there
- SteamCMD will ask for the account password interactively
- if Steam Guard is enabled, SteamCMD will also ask for the Steam Guard code
- in this tested setup, `anonymous` did not produce a working Linux install for `app_update 222860`

Expected files after install:

- `/home/steam/l4d2/srcds_run`
- `/home/steam/l4d2/srcds_linux`
- `/home/steam/l4d2/left4dead2`

### 5. Install Metamod and SourceMod

```bash
sudo -u steam -H bash -lc '
cd /home/steam/l4d2
curl -fsSL https://mms.alliedmods.net/mmsdrop/1.12/mmsource-1.12.0-git1219-linux.tar.gz -o /tmp/mmsource.tar.gz
tar -xzf /tmp/mmsource.tar.gz -C /home/steam/l4d2/left4dead2
curl -fsSL https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7223-linux.tar.gz -o /tmp/sourcemod.tar.gz
tar -xzf /tmp/sourcemod.tar.gz -C /home/steam/l4d2/left4dead2
mkdir -p /home/steam/l4d2/left4dead2/addons/sourcemod/plugins/disabled
if [ -f /home/steam/l4d2/left4dead2/addons/sourcemod/plugins/nextmap.smx ]; then
  mv /home/steam/l4d2/left4dead2/addons/sourcemod/plugins/nextmap.smx \
    /home/steam/l4d2/left4dead2/addons/sourcemod/plugins/disabled/
fi
'
```

If these exact URLs ever stop working, use the latest Linux `1.12` builds from AlliedModders and keep the same extraction paths.

### 6. Copy the template files

Copy the templates:

```bash
sudo install -o steam -g steam -m 644 /opt/l4d2-linux-server/templates/server.cfg \
  /home/steam/l4d2/left4dead2/cfg/server.cfg
sudo install -o steam -g steam -m 644 /opt/l4d2-linux-server/templates/sourcemod/admins_simple.ini \
  /home/steam/l4d2/left4dead2/addons/sourcemod/configs/admins_simple.ini
sudo install -o steam -g steam -m 644 /opt/l4d2-linux-server/templates/sourcemod/adminmenu_maplist.ini \
  /home/steam/l4d2/left4dead2/addons/sourcemod/configs/adminmenu_maplist.ini
sudo install -o root -g root -m 644 /opt/l4d2-linux-server/templates/systemd/l4d2.service \
  /etc/systemd/system/l4d2.service
```

Then edit the placeholders before starting the service:

- set a server name in `hostname` if you do not want to keep the default one
- set a real `rcon_password` in `/home/steam/l4d2/left4dead2/cfg/server.cfg`
- add your admin SteamIDs to `/home/steam/l4d2/left4dead2/addons/sourcemod/configs/admins_simple.ini`

The `systemd` template is already set up to listen on all interfaces, which is usually the safest option for the first start. If you later want to bind the server to one specific address, you can manually add `-ip <PUBLIC_IPV4>` to `ExecStart`.

### 7. Enable the service

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now l4d2.service
sudo systemctl status l4d2.service
ss -lntup | grep 27015
```

If the service does not start:

```bash
sudo journalctl -u l4d2 -n 100 --no-pager
```

Important:

- the service can be running locally even before external access works
- before testing from the game client, complete Step 8 and make sure the required ports are open both on the VPS and in the provider firewall

### 8. Open ports

At minimum:

- `27015/udp`
- `27015/tcp`
- `27000-27030/udp`
- `4380/udp`

Important:

- open these ports in the VPS operating system firewall if one is enabled
- also open them in the cloud provider firewall or security group if your provider uses one

## Connect to the server

In the in-game console:

```txt
connect example.com:27015
```

`example.com` is only an example.

Replace it with one of these:

- your own domain name with an `A` record pointing to the server's public IPv4 address
- the server's public IPv4 address directly, for example `connect 203.0.113.10:27015`

Important:

- for direct game connection, a normal `A` record to the public server IP is enough
- you do not have to use a domain at all if you prefer connecting by IP
- the `hostname` value in `server.cfg` is only the displayed server name, not the address players must use for connection

## Open the SourceMod admin menu

In the in-game console:

```txt
sm_admin
```

## Start Tank Challenge

First, make sure the map is installed on the server by following [docs/tank-challenge.md](docs/tank-challenge.md).

If you are already an admin on the server:

```txt
sm_map l4d2_tank_challenge_15_rounds
sm_map l4d2_tank_challenge_20_rounds
sm_map l4d2_tank_challenge_30_rounds
```

See [docs/tank-challenge.md](docs/tank-challenge.md) for the download and placement workflow.

## Daily operations

Check status:

```bash
sudo systemctl status l4d2
```

Restart:

```bash
sudo systemctl restart l4d2
```

Stop:

```bash
sudo systemctl stop l4d2
```

Start:

```bash
sudo systemctl start l4d2
```

View logs:

```bash
sudo journalctl -u l4d2 -f
```

## Admin setup

SourceMod admins are defined in:

- `addons/sourcemod/configs/admins_simple.ini`

Example:

```ini
"Admins"
{
    "STEAM_1:1:12345678" "99:z"
    "STEAM_1:0:87654321" "99:z"
}
```

Each admin gets a separate line. Multiple admins are fully supported.

## Caveats

### Players still need the custom map

This repository does not configure `FastDL`. If you switch the server to `Tank Challenge`, players should already have that map installed locally, or you should add a proper download delivery setup separately.

### Start on a stock map, switch to custom maps manually

It is safer to boot the service on a stock map such as `c2m1_highway`, then switch to custom content via `sm_map`.
