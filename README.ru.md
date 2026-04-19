[🇬🇧 English guide](README.md)

# Свой собственный сервер Left4Dead 2 на Ubuntu VPS за 20 минут

Скрипты и шаблоны, чтобы быстро развернуть публичный dedicated-сервер
`Left 4 Dead 2` на Ubuntu VPS и ставить карты из Steam Workshop без
танцев с бубном по форумным гайдам.

Что получается:

- native Linux бинарь (`srcds_linux`) под `systemd`
- `Metamod:Source` + `SourceMod` для админки
- идемпотентные скрипты на каждый шаг (пакеты → SteamCMD →
  Metamod + SourceMod → шаблоны → включение сервиса → проверка)
- универсальный установщик карт из Steam Workshop в одну команду
- Tank Challenge и Tropical Holdout как проверенные примеры карт

Собрано по реальному боевому развёртыванию на публичной VPS, а не по
старым форумным гайдам.

## Рекомендуемая площадка

Эта инструкция и сам проверочный боевой запуск выполнены именно на `cloud.ru Evolution free tier`.

По состоянию на `2026-04-18` для новых клиентов заявлены:

- бесплатная виртуальная машина `2 vCPU / 4 ГБ RAM / 30 ГБ`
- публичный IP оплачивается отдельно - около `150 ₽ в месяц`

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

Все `install-*.sh` идемпотентны — безопасно запускать их повторно на уже
настроенном хосте. Если нужно «пере-установить» какой-то шаг — удали
целевой файл, который он создаёт, и запусти скрипт снова.

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
sudo /opt/l4d2-linux-server/scripts/install-packages.sh
```

Создаёт пользователя `steam`, включает архитектуру `i386` и ставит пакеты,
нужные `srcds_linux`.

### 3. Поставить SteamCMD

```bash
sudo /opt/l4d2-linux-server/scripts/install-steamcmd.sh
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
sudo /opt/l4d2-linux-server/scripts/install-mms-sm.sh
```

Скачивает и распаковывает зафиксированные Linux-сборки `1.12` Metamod:Source
и SourceMod, а затем перемещает `nextmap.smx` в `plugins/disabled/`, чтобы
плагин не насильно менял карты.

Если AlliedModders снесёт эти конкретные сборки, поправь `MMS_URL` /
`SM_URL` в начале `scripts/install-mms-sm.sh` и запусти заново.

### 6. Скопировать шаблоны из репозитория

```bash
sudo /opt/l4d2-linux-server/scripts/install-templates.sh
```

Устанавливает `server.cfg`, `admins_simple.ini`, `adminmenu_maplist.ini` и
systemd-юнит `l4d2.service`. Уже существующие файлы НЕ перезаписываются —
повторный запуск не сотрёт твой `rcon_password` и `hostname`. Чтобы
переустановить шаблон с нуля, удали целевой файл и запусти снова.

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
sudo /opt/l4d2-linux-server/scripts/enable-service.sh
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
sudo /opt/l4d2-linux-server/scripts/verify-install.sh
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

## Установка кастомной карты из Steam Workshop

`install-workshop-map.sh` скачивает любую L4D2-карту из Workshop через
anonymous SteamCMD и кладёт её в `addons/workshop_<id>.vpk`.
Идемпотентный — если целевой VPK уже есть, скачивание пропускается;
чтобы перекачать, удали VPK первым.

Возьми id из URL айтема
(`steamcommunity.com/sharedfiles/filedetails/?id=<id>`) и запусти:

```bash
sudo /opt/l4d2-linux-server/scripts/install-workshop-map.sh <id>
```

Имя файла (`workshop_<id>.vpk`) можно переопределить вторым позиционным
аргументом, если хочется более говорящее:

```bash
sudo /opt/l4d2-linux-server/scripts/install-workshop-map.sh <id> <filename>.vpk
```

Чтобы вытащить имена карт (`sm_map` / `changelevel`) из установленного VPK:

```bash
sudo strings /home/steam/l4d2/left4dead2/addons/workshop_<id>.vpk \
  | grep -oE '^maps/[a-z0-9_]+\.bsp$' | sort -u
```

`workshop_download_item` работает с `anonymous` нормально, даже если
dedicated server ты ставил через Steam-аккаунт с купленной L4D2.

### Проверенные примеры

#### Tank Challenge

Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=151833267

```bash
sudo /opt/l4d2-linux-server/scripts/install-workshop-map.sh 151833267
```

Переключиться на карту в игре (админ SourceMod):

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

Переключиться на карту в игре (админ SourceMod):

```txt
sm_map pujo         # дневной вариант
sm_map pujonight    # ночной вариант
```

## Установка проверенных модов

Небольшой стек community-модов, все **работают server-side** (игрокам не
нужно ничего подписывать в Workshop). Вместе они дают умных survivor-ботов
и механизм «умер → выбрал живого бота → продолжил играть за него»,
так что соло-кооп не прерывается рестартом раунда когда ты умер.

SourceMod плагины (уходят в `addons/sourcemod/`):

- **hp_tank_show** ([source](https://github.com/fbef0102/L4D1_2-Plugins/tree/master/hp_tank_show)) —
  цветной спрайт над головой танка (зелёный → оранжевый → красный по
  мере потери HP, `R.I.P.` после смерти).
- **abm** — Advanced Bot Manager
  ([source](https://github.com/zonde306/l4d2sc/blob/master/l4d2_abm.sp),
  готовый бинарь в [Beats0/L4D2-Linux-Server-Package](https://github.com/Beats0/L4D2-Linux-Server-Package))
  — авто-спавнит survivor-ботов чтобы команда всегда была из 4, и при
  смерти игрока показывает **пронумерованное текстовое меню**, в котором
  можно выбрать любого живого бота и пересесть в него. Работает на
  обычных кампаниях и на arena-картах (Tank Challenge проверен).
- **left4dhooks** ([github](https://github.com/SilvDev/Left4DHooks)) —
  SourceMod-экстеншн, зависимость `hp_tank_show`.

Steam Workshop VScript-аддоны (уходят в `addons/` как VPK):

- **Left 4 Bots 2** ([Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3022416274) · [github](https://github.com/smilz0/Left4Bots)) —
  умный survivor AI: дефибят мёртвых, собирают канистры, идут за лидером,
  стреляют/уворачиваются умнее.
- **Left 4 Lib** ([Workshop](https://steamcommunity.com/workshop/filedetails/?id=2634208272)) —
  VScript-библиотека, зависимость Left 4 Bots 2.

Установить весь стек одной командой:

```bash
sudo /opt/l4d2-linux-server/scripts/install-mods.sh
sudo systemctl restart l4d2
```

Скрипт: SourceMod-файлы — через `curl`, Workshop-аддоны — через
`install-workshop-map.sh` (anonymous SteamCMD). Идемпотентный —
существующие файлы пропускаются; удали конкретный файл и запусти
снова, чтобы обновить его.

Проверить после рестарта через RCON:

```txt
sm plugins list
```

В выводе должны быть `ABM`, `[L4D1 & L4D2] Tank HP Sprite` и
`[L4D & L4D2] Left 4 DHooks Direct`. Left 4 Bots 2 — это VScript, а не
SourceMod, поэтому в `sm plugins list` он не виден — его загрузка
логируется при старте карты как `Including left4bots...` в
`journalctl -u l4d2`.

Ожидаемое поведение в игре:

- боты дефибят мёртвых, подбирают аптечки/гранаты, идут за лидером
- когда ты умер, появляется пронумерованное текстовое меню со списком
  живых ботов — жми цифру, пересаживаешься в выбранного бота и
  продолжаешь играть
- миссия не заканчивается пока жив хоть один survivor (бот или human)

Подкрутить `abm_offertakeover` / `abm_minplayers` в `cfg/sourcemod/abm.cfg`
и cvar'ы Left 4 Bots 2 в `left4dead2/left4bots2/cfg/convars.txt`, если
хочется менять дефолты.

### Нюанс про меню takeover для админа — выбирай только survivor-ботов

`abm_offertakeover 1` ограничивает меню только survivor-ботами для
обычных игроков, но **для админов ABM обходит этот фильтр** — админ в
меню видит всех живых ботов, включая заражённых (Tank, Boomer, Hunter,
Smoker, Jockey, Charger, Spitter).

**Выбирай в меню только survivor-имена**: Coach, Ellis, Nick, Rochelle,
Bill, Zoey, Francis, Louis.

Если случайно выбрал infected-бота на coop-карте, застрянешь на Infected
team и ни одна in-game команда надёжно не вернёт обратно. Рабочий фикс —
перезапустить сервис:

```bash
sudo systemctl restart l4d2
```

Это кикнет всех подключённых, так что используй только когда без
вариантов.

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
