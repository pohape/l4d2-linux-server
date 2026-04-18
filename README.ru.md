[🇬🇧 English guide](README.md)

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

## Проверенное окружение

- ОС: `Ubuntu 22.04`
- Архитектура: `x86_64`
- Путь установки сервера: `/home/steam/l4d2`
- Путь `SteamCMD`: `/home/steam/steamcmd`
- Публичный игровой порт: `27015`
- App ID L4D2 dedicated server: `222860`

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

## Структура репозитория

```text
.
├── README.md
├── README.ru.md
├── docs/
│   └── tank-challenge.md
├── scripts/
│   ├── _common.sh
│   ├── enable-service.sh
│   ├── install-mms-sm.sh
│   ├── install-packages.sh
│   ├── install-steamcmd.sh
│   ├── install-tank-challenge.sh
│   ├── install-templates.sh
│   └── verify-install.sh
└── templates/
    ├── server.cfg
    ├── sourcemod/
    │   ├── adminmenu_maplist.ini
    │   └── admins_simple.ini
    └── systemd/
        └── l4d2.service
```

Все `install-*.sh` идемпотентны — безопасно запускать их повторно на уже
настроенном хосте. `install-templates.sh` не перезаписывает существующие
конфиги, если не передать `FORCE=1`.

## Быстрый старт

### 1. Склонировать этот репозиторий

На некоторых минимальных Ubuntu-образах `git` не стоит из коробки, поэтому
первые две строки гарантируют его наличие:

```bash
sudo apt update
sudo apt install -y git
sudo mkdir -p /opt
sudo git clone https://github.com/pohape/l4d2-linux-server /opt/l4d2-linux-server
sudo chown -R "$USER":"$USER" /opt/l4d2-linux-server
```

Если репозиторий клонирован в другое место, поправь пути в следующих шагах.

### 2. Установить системные пакеты

```bash
sudo bash /opt/l4d2-linux-server/scripts/install-packages.sh
```

Создаёт пользователя `steam`, включает архитектуру `i386` и ставит пакеты,
нужные `srcds_linux`.

### 3. Поставить SteamCMD

```bash
sudo bash /opt/l4d2-linux-server/scripts/install-steamcmd.sh
```

Скачивает SteamCMD в `/home/steam/steamcmd` и создаёт симлинк
`~/.steam/sdk32/steamclient.so`.

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
sudo bash /opt/l4d2-linux-server/scripts/install-mms-sm.sh
```

Скачивает и распаковывает зафиксированные Linux-сборки `1.12` Metamod:Source
и SourceMod, а затем перемещает `nextmap.smx` в `plugins/disabled/`, чтобы
плагин не насильно менял карты.

Если AlliedModders снесёт эти конкретные сборки, URL можно переопределить:

```bash
sudo MMS_URL=... SM_URL=... bash /opt/l4d2-linux-server/scripts/install-mms-sm.sh
```

### 6. Скопировать шаблоны из репозитория

```bash
sudo bash /opt/l4d2-linux-server/scripts/install-templates.sh
```

Устанавливает `server.cfg`, `admins_simple.ini`, `adminmenu_maplist.ini` и
systemd-юнит `l4d2.service`. По умолчанию уже существующие файлы НЕ
перезаписываются, так что повторный запуск не сотрёт твой `rcon_password` и
`hostname`. Если нужно переустановить — `FORCE=1`, исходный файл будет
сохранён как `<dst>.bak.<timestamp>`.

Потом обязательно отредактировать placeholders перед запуском сервиса:

- задать своё имя сервера в `hostname`, если не хочешь оставлять значение по умолчанию
- задать реальный `rcon_password` в `/home/steam/l4d2/left4dead2/cfg/server.cfg`
- добавить свои SteamID админов в `/home/steam/l4d2/left4dead2/addons/sourcemod/configs/admins_simple.ini`

Как найти свой SteamID:

1. открой свой профиль Steam в браузере и скопируй его ссылку
2. вставь ссылку на [steamid.io](https://steamid.io)
3. скопируй значение, указанное как **steamID** (вида `STEAM_0:1:12345678`)
4. вставь эту строку в `admins_simple.ini`

Шаблон `systemd` уже настроен так, чтобы сервер слушал на всех интерфейсах. Это обычно удобнее и безопаснее для первого запуска. Если позже захочешь жёстко привязать сервер к конкретному адресу, можешь вручную добавить `-ip <PUBLIC_IPV4>` в `ExecStart`.

Если ты меняешь эти файлы уже после запуска сервиса, сделай:

```bash
sudo systemctl restart l4d2
```

### 7. Включить сервис и проверить установку

```bash
sudo bash /opt/l4d2-linux-server/scripts/enable-service.sh
```

Делает `daemon-reload`, включает и запускает `l4d2.service`, затем
автоматически запускает `verify-install.sh`. Скрипт проверяет пользователя
`steam`, `i386`-библиотеки, бинарники сервера, файлы `Metamod` и `SourceMod`,
`rcon_password`, админов, `systemd`-юнит, порт `27015` и последние 200 строк
логов. Код возврата `0`, если всё критичное прошло, иначе ненулевой.

Важно:

- сервис может уже работать локально, даже если снаружи к нему ещё нельзя подключиться
- перед проверкой подключения из игры обязательно выполни шаг 8 и убедись, что нужные порты открыты и на самой VPS, и в firewall провайдера

Если что-то упало, посмотри логи сервиса:

```bash
sudo journalctl -u l4d2 -n 100 --no-pager
```

Повторно прогнать проверки можно в любой момент:

```bash
sudo bash /opt/l4d2-linux-server/scripts/verify-install.sh
```

### 8. Открыть порты

Минимально:

- `27015/udp`
- `27015/tcp`
- `27000-27030/udp`
- `4380/udp`

Важно:

- открой эти порты в локальном firewall самой VPS, если он включён
- также открой эти порты в firewall/security group у облачного провайдера, если он используется

Если на VPS используется `ufw`:

```bash
sudo ufw allow 27015/udp
sudo ufw allow 27015/tcp
sudo ufw allow 27000:27030/udp
sudo ufw allow 4380/udp
sudo ufw status
```

## Как подключаться

Сначала включи developer console в настройках самой игры, если она у тебя ещё выключена.

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

Developer console в игре тоже должна быть включена.

В игровой консоли:

```txt
sm_admin
```

## Как запустить Tank Challenge

Установить карту:

```bash
sudo bash /opt/l4d2-linux-server/scripts/install-tank-challenge.sh
```

Скрипт скачивает workshop-айтем через anonymous SteamCMD и кладёт `.vpk` в
`addons/`. Идемпотентный — если VPK уже есть, скачивание пропускается
(передай `FORCE=1`, чтобы перекачать).

Для этой карты `workshop_download_item` с `anonymous` работает нормально,
даже если сам dedicated server ты ставил через Steam-аккаунт с купленной
L4D2.

Если у тебя уже есть админ-права, переключиться на карту в игре:

```txt
sm_map l4d2_tank_challenge_15_rounds
sm_map l4d2_tank_challenge_20_rounds
sm_map l4d2_tank_challenge_30_rounds
```

Подробности по workshop-скачиванию см. в [docs/tank-challenge.md](docs/tank-challenge.md).

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

- `/home/steam/l4d2/left4dead2/addons/sourcemod/configs/admins_simple.ini`

Пример:

```ini
"Admins"
{
    "STEAM_1:1:12345678" "99:z"
    "STEAM_1:0:87654321" "99:z"
}
```

Каждый админ добавляется отдельной строкой.

Чтобы добавить нового админа на уже работающий сервер — найди его SteamID тем же способом, что и в шаге 6, вставь строку в `admins_simple.ini` и применяй:

```bash
sudo systemctl restart l4d2
```

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
