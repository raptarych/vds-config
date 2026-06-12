# VDS Config

Быстрый деплой WireGuard VPN и Telegram MTProto Proxy на Ubuntu 24.04.

## Что ставится

| Сервис | Образ | Порт | Описание |
|---|---|---|---|
| **WireGuard** | `weejewel/wg-easy` | `51820/UDP`, `51821/TCP` | VPN с веб-панелью |
| **MTProto Proxy** | `telegrammessenger/proxy` | `484/TCP` | Telegram-прокси с Fake TLS |

## Установка

```bash
git clone https://github.com/raptarych/vds-config.git
cd vds-config
bash ubuntu.sh
```

Скрипт:
1. Определяет внешний IP сервера
2. Спрашивает пароль для панели WireGuard
3. Ставит Docker и Docker Compose (если нет)
4. Генерирует секрет для MTProto Proxy с Fake TLS (домен `gosuslugi.ru`)
5. Поднимает контейнеры
6. Выдаёт ссылки для подключения

## Результат

После запуска скрипт выведет:

- **Ссылку для Telegram** — `tg://proxy?...` и `https://t.me/proxy?...`
- **Адрес панели WireGuard** — `http://<IP>:51821/`

## Данные

Все конфиги хранятся в `~/.vds/`:

- `~/.vds/wg-easy/` — конфиги WireGuard
- `~/.vds/proxy-config/` — конфиги прокси
- `.env` — переменные (IP, пароль, секрет)

## Перезапуск

```bash
sudo docker compose --env-file .env up -d
```

## Остановка

```bash
sudo docker compose --env-file .env down --remove-orphans
```
