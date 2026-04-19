[🇷🇺 Russian guide is available here](README.ru.md)

# Set Up a Left 4 Dead 2 Server on Ubuntu VPS in 20 Minutes

Scripts and templates to set up a public `Left 4 Dead 2` dedicated server
on an Ubuntu VPS quickly, and to install Steam Workshop maps without the
usual forum-guide hassle.

What you get:

- native Linux binaries (`srcds_linux`) under `systemd`
- `Metamod:Source` + `SourceMod` admin access
- idempotent install scripts for every step (packages → SteamCMD →
  Metamod + SourceMod → templates → service enable → verify)
- a single-command Steam Workshop map installer
- Tank Challenge and Tropical Holdout as verified map examples

Based on a real deployment on a public VPS, not on old forum guides.

## Minimum VPS specs

Comfortable baseline, verified on a real public deployment:

- 2 vCPU
- 2 GB RAM (server + OS; 4 GB is roomy)
- 20 GB disk (Ubuntu ~4 GB + game ~10 GB + headroom; 30 GB is roomy)
- Ubuntu 22.04 or 24.04 LTS, x86_64
- a public IPv4

`srcds_linux` typically uses ~250–500 MB RAM and occupies one core under
full 8-player load. Bandwidth per player is ~30–50 KB/s (4 players ≈
2 Mbit/s), which fits inside any VPS's included traffic.

## Recommended hosting

Verified on [Tencent Cloud Lighthouse](https://www.tencentcloud.com/products/lighthouse)
(Frankfurt region) on their intro promo tier:

- **~$10 USD for the first year** (renews at roughly $50/year)
- 2 vCPU, 2 GB RAM, 40 GB SSD
- public IPv4 via NAT — inside the VM `eth0` shows a private address
  (e.g. `10.9.x.x`); you connect from the outside to the mapped public
  IP shown in the Lighthouse console
- bandwidth capped around ~3 Mbit/s on the promo tier — enough for a
  full 4-player L4D2 session, but the initial SteamCMD download of
  ~10 GB will take a while (plan for 30+ min)

Pick **Ubuntu 22.04 LTS** when creating the VM (primary verified
baseline). Ubuntu 24.04 LTS has also been verified end-to-end.

> **Lighthouse has its own built-in firewall** that blocks every
> inbound port except SSH (22) by default — the OS-level firewall
> inside the VM (`iptables`/`ufw`) is irrelevant if the Lighthouse
> edge firewall is closed. When you reach Step 8 below, open the game
> ports in the Lighthouse console under the instance's **Firewall**
> tab (not "Security groups"):
>
> - UDP 27015, TCP 27015
> - UDP 27000–27030
> - UDP 4380
>
> source `0.0.0.0/0`. Without these rules the server is unreachable
> from outside even though it is running inside the VM.

Promo pricing, region list and bandwidth caps change over time — check
the current terms in the Tencent Cloud console before buying.

## Important notes

Select OS: Ubuntu 22.04 or 24.04 LTS (both verified).

### The server install required a real Steam account with owned L4D2

In this deployment, `anonymous` login did not produce a working Linux install for `app_update 222860`.

What worked:

1. Log into `SteamCMD` with a normal Steam account.
2. That account must own `Left 4 Dead 2`.
3. Run `app_update 222860 validate`.

### The server is still a 32-bit workload

On `Ubuntu 22.04` / `24.04`, install the `i386` runtime packages before downloading the game.

## Repository layout

```text
.
├── README.md
├── README.ru.md
├── scripts/
│   ├── _common.sh
│   ├── enable-service.sh
│   ├── install-mms-sm.sh
│   ├── install-mods.sh
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

All the `install-*.sh` scripts are idempotent — safe to re-run on an
already configured host. If you want to force a step to re-do itself,
delete the target file(s) it produced, then re-run.

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
sudo /opt/l4d2-linux-server/scripts/install-packages.sh
```

Creates the `steam` user, enables the `i386` architecture, and installs the
runtime packages required by `srcds_linux`.

### 3. Install SteamCMD

```bash
sudo /opt/l4d2-linux-server/scripts/install-steamcmd.sh
```

Downloads SteamCMD into `/home/steam/steamcmd` and creates the
`~/.steam/sdk32/steamclient.so` symlink.

### 4. Install the L4D2 dedicated server

```bash
sudo -u steam -H bash -lc 'cd /home/steam/steamcmd && ./steamcmd.sh'
```

Inside the SteamCMD console, enter these **in this exact order** — do
not skip `force_install_dir` or put it after `login`:

```txt
force_install_dir /home/steam/l4d2
login <steam_login>
app_update 222860 validate
quit
```

Notes:

- `force_install_dir` MUST be the first line. If you run `login` before
  it, SteamCMD installs into its own default
  (`~/Steam/steamapps/common/Left 4 Dead 2 Dedicated Server/`) and the
  scripts in this repo will not find the game.
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
sudo /opt/l4d2-linux-server/scripts/install-mms-sm.sh
```

Downloads and extracts the pinned Linux `1.12` builds of Metamod:Source and
SourceMod, and moves `nextmap.smx` into `plugins/disabled/` so the plugin
does not force map rotation.

If AlliedModders ever retires those exact builds, edit `MMS_URL` /
`SM_URL` at the top of `scripts/install-mms-sm.sh` before running it.

### 6. Copy the template files

```bash
sudo /opt/l4d2-linux-server/scripts/install-templates.sh
```

Installs `server.cfg`, `admins_simple.ini`, `adminmenu_maplist.ini`, and the
`l4d2.service` unit. Existing files are NOT overwritten, so re-runs will
not clobber your `rcon_password` or `hostname`. To reinstall a template
from scratch, delete the target file first then re-run.

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
sudo /opt/l4d2-linux-server/scripts/enable-service.sh
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
sudo /opt/l4d2-linux-server/scripts/verify-install.sh
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
SteamCMD and copies the `.vpk` into `addons/workshop_<id>.vpk`.
Idempotent — skips the download if the target VPK already exists; to
re-download, delete the VPK first.

Pick the item id from its Workshop URL
(`steamcommunity.com/sharedfiles/filedetails/?id=<id>`) and run:

```bash
sudo /opt/l4d2-linux-server/scripts/install-workshop-map.sh <id>
```

The installed filename (`workshop_<id>.vpk`) can be overridden with a
second positional argument if you prefer a friendlier name:

```bash
sudo /opt/l4d2-linux-server/scripts/install-workshop-map.sh <id> <filename>.vpk
```

To list the `sm_map` / `changelevel` names inside an installed VPK:

```bash
sudo strings /home/steam/l4d2/left4dead2/addons/workshop_<id>.vpk \
  | grep -oE '^maps/[a-z0-9_]+\.bsp$' | sort -u
```

### Verified examples

#### Tank Challenge

Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=151833267

```bash
sudo /opt/l4d2-linux-server/scripts/install-workshop-map.sh 151833267
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
sudo /opt/l4d2-linux-server/scripts/install-workshop-map.sh 1432537029
```

Switch to it in-game (as a SourceMod admin):

```txt
sm_map pujo         # day variant
sm_map pujonight    # night variant
```

## Install verified mods

A small stack of community mods that all deploy server-side (no client
subscription required). Together they give smart survivor bots and a
proper «die → pick a bot to take over» flow, so a solo coop run keeps
going after you die instead of restarting the round.

SourceMod plugins (fetched into `addons/sourcemod/`):

- **hp_tank_show** ([source](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/hp_tank_show))
  — color-coded sprite over a tank's head (green → orange → red with HP,
  `R.I.P.` on death).
- **abm** — Advanced Bot Manager
  ([source](https://github.com/zonde306/l4d2sc/blob/master/l4d2_abm.sp),
  prebuilt binary in [Beats0/L4D2-Linux-Server-Package](https://github.com/Beats0/L4D2-Linux-Server-Package))
  — auto-spawns survivor bots to keep the team at 4, and on player death
  shows a numbered text menu so you can pick any living bot to take
  over. Works on standard campaigns and on arena maps (Tank Challenge
  verified).
- **left4dhooks** ([github](https://github.com/SilvDev/Left4DHooks))
  — required SourceMod extension for `hp_tank_show`.

Steam Workshop VScript addons (fetched into `addons/` as VPKs):

- **Left 4 Bots 2** ([Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3022416274) · [github](https://github.com/smilz0/Left4Bots))
  — smart survivor AI: defib dead players, scavenge gas cans, follow
  leader, smarter combat.
- **Left 4 Lib** ([Workshop](https://steamcommunity.com/workshop/filedetails/?id=2634208272))
  — required VScript library for Left 4 Bots 2.

Install the whole stack in one shot:

```bash
sudo /opt/l4d2-linux-server/scripts/install-mods.sh
sudo systemctl restart l4d2
```

The script downloads the SourceMod files via `curl` and the Workshop
addons via `install-workshop-map.sh` (anonymous SteamCMD). Idempotent —
existing files are skipped; delete a specific file and re-run to refresh
it.

Verify after restart via RCON:

```txt
sm plugins list
```

You should see `ABM`, `[L4D1 & L4D2] Tank HP Sprite`, and
`[L4D & L4D2] Left 4 DHooks Direct`. Left 4 Bots 2 is VScript, not
SourceMod, so it does not show up there — its load is logged at map
start as `Including left4bots...` in `journalctl -u l4d2`.

Expected in-game behaviour:

- survivor bots defib dead players, pick up meds/throwables, follow leader
- when you die, a numbered text menu appears listing the live bots —
  press a digit to take over that bot and keep playing
- mission keeps going as long as any survivor (bot or human) is alive

Tune `abm_offertakeover` / `abm_minplayers` in `cfg/sourcemod/abm.cfg`
and Left 4 Bots 2 cvars in `left4dead2/left4bots2/cfg/convars.txt` if
you want to change defaults.

### Admin note on the takeover menu — pick survivor bots only

ABM restricts the menu to survivor bots for non-admin
players, but ABM **bypasses that filter for admins** — as an admin you
see every living bot, including infected ones (Tank, Boomer, Hunter,
Smoker, Jockey, Charger, Spitter).

**Only pick survivor-named entries** from the menu: Coach, Ellis, Nick,
Rochelle, Bill, Zoey, Francis, Louis.

If you accidentally pick an infected bot on a coop map, you get stuck on
the Infected team and no in-game command reliably brings you back. The
only working fix is to restart the service:

```bash
sudo systemctl restart l4d2
```

This kicks everyone connected, so use it sparingly.

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
- did not add your SteamID to `admins_simple.ini`, then tried to open `sm_admin`
- tried to switch the server to `Tank Challenge` without installing the map first

### Start on a stock map, switch to custom maps manually

It is safer to boot the service on a stock map such as `c2m1_highway`, then switch to custom content via `sm_map`.
