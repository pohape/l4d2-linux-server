# l4d2-linux-server

Практические шаблоны и инструкция по запуску публичного сервера `Left 4 Dead 2` на `Ubuntu 22.04` с:

- native Linux сервером
- управлением через `systemd`
- `Metamod:Source`
- `SourceMod`
- кастомными картами
- рабочим примером `Tank Challenge v1.5`

Эта инструкция собрана по реальному боевому развёртыванию на VPS.

## Рекомендуемая площадка

Эта инструкция и сам проверочный боевой запуск выполнены именно на `cloud.ru Evolution free tier`.

По состоянию на `2026-04-18` для новых клиентов заявлены:

- бесплатная виртуальная машина `2 vCPU / 4 ГБ RAM / 30 ГБ`
- публичный IP оплачивается отдельно, примерно `146-147 ₽ в месяц`, то есть практически около `150 ₽ в месяц`

Для одного своего публичного L4D2 сервера этого хватает. Это проверено на реальном запуске:

- native Linux L4D2 dedicated server
- `SourceMod`
- `Metamod:Source`
- кастомная карта `Tank Challenge`

Важно:

- free tier и тарифы у провайдера могут измениться, поэтому перед заказом лучше перепроверить актуальные условия в его веб-интерфейсе и документации
- на практике для публичной доступности сервера потребуется не только создать VM, но и отдельно подключить публичный IP

## Что важно знать заранее

### Native Linux сервер

L4D2 dedicated server нормально работает на Linux нативно через `srcds_linux`.

### Для установки сервера понадобился обычный Steam-аккаунт с купленной L4D2

На практике `anonymous` login не дал рабочую Linux-установку для `app_update 222860`.

Сработал путь:

1. Войти в `SteamCMD` под обычным Steam-аккаунтом.
2. У аккаунта должна быть куплена `Left 4 Dead 2`.
3. Выполнить `app_update 222860 validate`.

### Серверная часть остаётся 32-битной

На `Ubuntu 22.04` заранее нужны `i386` библиотеки.

## Быстрый старт

### 1. Установить системные пакеты

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

### 2. Склонировать этот репозиторий

```bash
sudo mkdir -p /opt
sudo git clone https://github.com/pohape/l4d2-linux-server /opt/l4d2-linux-server
sudo chown -R "$USER":"$USER" /opt/l4d2-linux-server
```

Если репозиторий клонирован в другое место, поправь пути в следующих шагах.

### 3. Поставить SteamCMD вручную

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

### 4. Установить L4D2 dedicated server

```bash
sudo -u steam -H bash -lc 'cd /home/steam/steamcmd && ./steamcmd.sh'
```

Внутри `SteamCMD`:

```txt
force_install_dir /home/steam/l4d2
login <steam_login>
app_update 222860 validate
quit
```

Примечания:

- `login <steam_login>` это placeholder, туда нужно подставить свой реальный логин Steam
- пароль `Steam` будет запрошен интерактивно
- если включён `Steam Guard`, `SteamCMD` дополнительно попросит код `Steam Guard`
- в этом проверенном сценарии `anonymous` не дал рабочую Linux-установку для `app_update 222860`

После установки должны появиться:

- `/home/steam/l4d2/srcds_run`
- `/home/steam/l4d2/srcds_linux`
- `/home/steam/l4d2/left4dead2`

### 5. Установить Metamod и SourceMod

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

Если эти точные URL когда-нибудь перестанут работать, нужно взять свежие Linux-сборки ветки `1.12` с AlliedModders и распаковать их в те же каталоги.

### 6. Скопировать шаблоны из репозитория

Скопировать шаблоны:

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

Потом обязательно отредактировать placeholders перед запуском сервиса:

- задать своё имя сервера в `hostname`, если не хочешь оставлять значение по умолчанию
- задать реальный `rcon_password` в `/home/steam/l4d2/left4dead2/cfg/server.cfg`
- добавить свои SteamID админов в `/home/steam/l4d2/left4dead2/addons/sourcemod/configs/admins_simple.ini`

Шаблон `systemd` уже настроен так, чтобы сервер слушал на всех интерфейсах. Это обычно удобнее и безопаснее для первого запуска. Если позже захочешь жёстко привязать сервер к конкретному адресу, можешь вручную добавить `-ip <PUBLIC_IPV4>` в `ExecStart`.

### 7. Включить systemd сервис

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now l4d2.service
sudo systemctl status l4d2.service
ss -lntup | grep 27015
```

Если сервис не поднялся:

```bash
sudo journalctl -u l4d2 -n 100 --no-pager
```

Важно:

- сервис может уже работать локально, даже если снаружи к нему ещё нельзя подключиться
- перед проверкой подключения из игры обязательно выполни шаг 8 и убедись, что нужные порты открыты и на самой VPS, и в firewall провайдера

### 8. Открыть порты

Минимально:

- `27015/udp`
- `27015/tcp`
- `27000-27030/udp`
- `4380/udp`

Важно:

- открой эти порты в локальном firewall самой VPS, если он включён
- также открой эти порты в firewall/security group у облачного провайдера, если он используется

## Как подключаться

В игровой консоли:

```txt
connect example.ru:27015
```

`example.ru` здесь только пример.

Замени его на один из вариантов:

- свой домен, у которого `A`-запись указывает на публичный IPv4 сервера
- либо прямо на публичный IPv4 сервера, например `connect 203.0.113.10:27015`

Важно:

- для обычного подключения к игровому серверу достаточно обычной `A`-записи на публичный IP сервера
- домен вообще не обязателен, можно подключаться просто по IP
- `hostname` в `server.cfg` это только отображаемое имя сервера, а не адрес, по которому игроки обязаны подключаться

## Как открыть админку

В игровой консоли:

```txt
sm_admin
```

## Как запустить Tank Challenge

Сначала карта должна быть установлена на сервер.

Минимальный рабочий путь:

```bash
sudo -u steam -H bash -lc '
cd /home/steam/steamcmd
./steamcmd.sh +login anonymous +workshop_download_item 550 151833267 validate +quit
cp /home/steam/Steam/steamapps/workshop/content/550/151833267/299860065267327837_legacy.bin \
  /home/steam/l4d2/left4dead2/addons/l4d2_tank_challenge.vpk
'
```

Для этой карты `workshop_download_item` с `anonymous` работает нормально, даже если сам dedicated server ты ставил через Steam-аккаунт с купленной L4D2.

Если нужен более подробный разбор, см. [docs/tank-challenge.md](docs/tank-challenge.md).

Если у тебя уже есть админ-права:

```txt
sm_map l4d2_tank_challenge_15_rounds
sm_map l4d2_tank_challenge_20_rounds
sm_map l4d2_tank_challenge_30_rounds
```

Подробности по установке карты в [docs/tank-challenge.md](docs/tank-challenge.md).

## Повседневное управление сервером

Статус:

```bash
sudo systemctl status l4d2
```

Перезапуск:

```bash
sudo systemctl restart l4d2
```

Остановка:

```bash
sudo systemctl stop l4d2
```

Запуск:

```bash
sudo systemctl start l4d2
```

Логи:

```bash
sudo journalctl -u l4d2 -f
```

## Админы SourceMod

Админы задаются в:

- `addons/sourcemod/configs/admins_simple.ini`

Пример:

```ini
"Admins"
{
    "STEAM_1:1:12345678" "99:z"
    "STEAM_1:0:87654321" "99:z"
}
```

Каждый админ добавляется отдельной строкой.

## Ограничения

### Игрокам нужна кастомная карта

В репозитории не настраивается `FastDL`. Если сервер переключается на `Tank Challenge`, игрокам лучше заранее иметь карту локально.

### Что я бы считал основными точками отказа на чистом VPS

- забыли открыть порты в веб-интерфейсе провайдера
- забыли открыть порты в локальном firewall самой VPS
- попытались ставить сервер через `anonymous`, а не через Steam-аккаунт с купленной L4D2
- не добавили свой SteamID в `admins_simple.ini`, а потом пытаются открыть `sm_admin`
- пытаются переключить сервер на `Tank Challenge`, не установив карту заранее

### Лучше стартовать сервис на стандартной карте

Практически безопаснее поднимать сервис на `c2m1_highway`, а на кастомную карту переключаться потом через `sm_map`.
