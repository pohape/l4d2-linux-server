# Tank Challenge v1.5

This map was verified in a real Linux deployment of a public L4D2 server.

## Workshop item

- Workshop item id: `151833267`

## Download with SteamCMD

```bash
sudo -u steam -H bash -lc '
cd /home/steam/steamcmd
./steamcmd.sh +login anonymous +workshop_download_item 550 151833267 validate +quit
'
```

## Resulting file

After download, the map may arrive as a `.bin` file even though it is actually a VPK:

```text
/home/steam/Steam/steamapps/workshop/content/550/151833267/299860065267327837_legacy.bin
```

That is expected for this item.

## Install it into the server

```bash
sudo -u steam cp \
  /home/steam/Steam/steamapps/workshop/content/550/151833267/299860065267327837_legacy.bin \
  /home/steam/l4d2/left4dead2/addons/l4d2_tank_challenge.vpk
```

## Map names

Use one of these:

- `l4d2_tank_challenge_15_rounds`
- `l4d2_tank_challenge_20_rounds`
- `l4d2_tank_challenge_30_rounds`

## Switch to the map

In-game as SourceMod admin:

```txt
sm_map l4d2_tank_challenge_15_rounds
```

Or from RCON:

```txt
changelevel l4d2_tank_challenge_15_rounds
```

## Important note for players

Without `FastDL`, players should already have the map installed locally before joining the server on this custom map.
