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
├── scripts/
│   ├── _common.sh
│   ├── enable-service.sh
│   ├── install-mms-sm.sh
│   ├── install-packages.sh
│   ├── install-steamcmd.sh
│   ├── install-templates.sh
│   ├── install-workshop-map.sh
│   └── verify-install.sh
└── templates/
    ├── server.cfg
    ├── sourcemod/
    │   ├── adminmenu_maplist.ini
    │   └── admins_simple.ini
    └── systemd/
        └── l4d2.service
```

All the `install-*.sh` scripts are idempotent: it's safe to re-run them on
an already configured host. The `install-templates.sh` script will not
overwrite existing config files unless you pass `FORCE=1`.

## Quick start

### 1. Clone this repository

Some minimal Ubuntu cloud images do not ship with `git` preinstalled, so the
first two lines guarantee it is available:

```bash
sudo apt update
sudo apt install -y git
sudo mkdir -p /opt
sudo git clone https://github.com/pohape/l4d2-linux-server /opt/l4d2-linux-server
sudo chown -R "$USER":"$USER" /opt/l4d2-linux-server
```

If you cloned the repo somewhere else, adjust the paths in the next steps.

### 2. Install system packages

```bash
sudo bash /opt/l4d2-linux-server/scripts/install-packages.sh
```

Creates the `steam` user, enables the `i386` architecture, and installs the
runtime packages required by `srcds_linux`.

### 3. Install SteamCMD

```bash
sudo bash /opt/l4d2-linux-server/scripts/install-steamcmd.sh
```

Downloads SteamCMD into `/home/steam/steamcmd` and creates the
`~/.steam/sdk32/steamclient.so` symlink.

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
sudo bash /opt/l4d2-linux-server/scripts/install-mms-sm.sh
```

Downloads and extracts the pinned Linux `1.12` builds of Metamod:Source and
SourceMod, and moves `nextmap.smx` into `plugins/disabled/` so the plugin
does not force map rotation.

If AlliedModders ever retires those exact builds, override the URLs:

```bash
sudo MMS_URL=... SM_URL=... bash /opt/l4d2-linux-server/scripts/install-mms-sm.sh
```

### 6. Copy the template files

```bash
sudo bash /opt/l4d2-linux-server/scripts/install-templates.sh
```

Installs `server.cfg`, `admins_simple.ini`, `adminmenu_maplist.ini`, and the
`l4d2.service` unit. By default, existing files are NOT overwritten, so
re-runs will not clobber your `rcon_password` or `hostname`. Pass `FORCE=1`
to back up the existing file (to `<dst>.bak.<timestamp>`) and replace it.

Then edit the placeholders before starting the service:

- set a server name in `hostname` if you do not want to keep the default one
- set a real `rcon_password` in `/home/steam/l4d2/left4dead2/cfg/server.cfg`
- add your admin SteamIDs to `/home/steam/l4d2/left4dead2/addons/sourcemod/configs/admins_simple.ini`

To find your SteamID:

1. open your Steam profile in a browser and copy its URL
2. paste the URL into [steamid.io](https://steamid.io)
3. copy the value shown as **steamID** (looks like `STEAM_0:1:12345678`)
4. paste that line into `admins_simple.ini`

The `systemd` template is already set up to listen on all interfaces, which is usually the safest option for the first start. If you later want to bind the server to one specific address, you can manually add `-ip <PUBLIC_IPV4>` to `ExecStart`.

If you change these files later after the service is already running, restart it:

```bash
sudo systemctl restart l4d2
```

### 7. Enable the service and verify the install

```bash
sudo bash /opt/l4d2-linux-server/scripts/enable-service.sh
```

This reloads systemd, enables and starts `l4d2.service`, and then runs
`verify-install.sh`. The verification checks the `steam` user, the `i386`
runtime packages, the server binaries, Metamod and SourceMod files,
`rcon_password`, admins, the `systemd` unit, port `27015`, and the last 200
log lines. Exit code is `0` when everything required passes, non-zero
otherwise.

Important:

- the service can be running locally even before external access works
- before testing from the game client, complete Step 8 and make sure the required ports are open both on the VPS and in the provider firewall

If something fails, inspect the service logs:

```bash
sudo journalctl -u l4d2 -n 100 --no-pager
```

You can re-run `verify-install.sh` any time:

```bash
sudo bash /opt/l4d2-linux-server/scripts/verify-install.sh
```

### 8. Open ports

At minimum:

- `27015/udp`
- `27015/tcp`
- `27000-27030/udp`
- `4380/udp`

Important:

- open these ports in the VPS operating system firewall if one is enabled
- also open them in the cloud provider firewall or security group if your provider uses one

If the VPS uses `ufw`:

```bash
sudo ufw allow 27015/udp
sudo ufw allow 27015/tcp
sudo ufw allow 27000:27030/udp
sudo ufw allow 4380/udp
sudo ufw status
```

## Connect to the server

First, enable the developer console in the game settings if it is not enabled yet.

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

The developer console in the game must be enabled as well.

In the in-game console:

```txt
sm_admin
```

## Install a custom map from the Steam Workshop

`install-workshop-map.sh` downloads any L4D2 Workshop map via anonymous
SteamCMD and copies the `.vpk` into `addons/workshop_<id>.vpk`. Idempotent —
skips the download if the target VPK already exists (pass `FORCE=1` to
re-download).

Pick the item id from its Workshop URL
(`steamcommunity.com/sharedfiles/filedetails/?id=<WORKSHOP_ITEM>`) and run:

```bash
sudo WORKSHOP_ITEM=<id> bash /opt/l4d2-linux-server/scripts/install-workshop-map.sh
```

The installed filename (`workshop_<id>.vpk`) can be overridden with
`VPK_NAME=…` if you prefer a friendlier name.

To list the `sm_map` / `changelevel` names inside an installed VPK:

```bash
sudo strings /home/steam/l4d2/left4dead2/addons/workshop_<id>.vpk \
  | grep -oE '^maps/[a-z0-9_]+\.bsp$' | sort -u
```

### Verified examples

#### Tank Challenge

Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=151833267

```bash
sudo WORKSHOP_ITEM=151833267 bash /opt/l4d2-linux-server/scripts/install-workshop-map.sh
```

Switch to it in-game (as a SourceMod admin):

```txt
sm_map l4d2_tank_challenge_15_rounds
sm_map l4d2_tank_challenge_20_rounds
sm_map l4d2_tank_challenge_30_rounds
```

#### Tropical Holdout

Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=1432537029

```bash
sudo WORKSHOP_ITEM=1432537029 bash /opt/l4d2-linux-server/scripts/install-workshop-map.sh
```

Switch to it in-game (as a SourceMod admin):

```txt
sm_map pujo         # day variant
sm_map pujonight    # night variant
```

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

- `/home/steam/l4d2/left4dead2/addons/sourcemod/configs/admins_simple.ini`

Example:

```ini
"Admins"
{
    "STEAM_1:1:12345678" "99:z"
    "STEAM_1:0:87654321" "99:z"
}
```

Each admin gets a separate line. Multiple admins are fully supported.

To add a new admin to a running server, find their SteamID the same way as in step 6, paste the line into `admins_simple.ini`, and apply the change:

```bash
sudo systemctl restart l4d2
```

## Caveats

### Players still need the custom map

This repository does not configure `FastDL`. If you switch the server to `Tank Challenge`, players should already have that map installed locally, or you should add a proper download delivery setup separately.

### Common failure modes on a clean VPS

- forgot to open the required ports in the cloud provider's web UI
- forgot to open the required ports in the VPS's own firewall
- tried to install the server with `anonymous` instead of a Steam account that owns L4D2
- did not add their SteamID to `admins_simple.ini`, then tried to open `sm_admin`
- tried to switch the server to `Tank Challenge` without installing the map first

### Start on a stock map, switch to custom maps manually

It is safer to boot the service on a stock map such as `c2m1_highway`, then switch to custom content via `sm_map`.
