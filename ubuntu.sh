#!/bin/bash

# Конфигурация для Ubuntu 24.04

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

EXTERNAL_IP=$(curl -4 ifconfig.me)
if [[ -z "$EXTERNAL_IP" ]]; then
	echo -e "${RED}Пустой EXTERNAL_IP${NC}"
	exit 1
fi

echo -e "Detected external IP of VPS:${GREEN} $EXTERNAL_IP ${NC}"
read -s -p "Enter password for WireGuard UI: " WG_PANEL_PASSWORD
echo ""

# Docker
if ! command -v docker &> /dev/null; then
	curl -fsSL https://get.docker.com -o get-docker.sh
	sudo sh get-docker.sh
else
    echo -e "${YELLOW}Docker установлен, пропускаем его установку${NC}"
fi

# Docker Compose
if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
	echo -e "${YELLOW}Устанавливаем Docker Compose${NC}"
	DIRECTORY=$(dirname $(realpath $(which docker)))
	curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o "$DIRECTORY/docker-compose"
	chmod +x "$DIRECTORY/docker-compose"
else
    echo -e "${YELLOW}Docker Compose установлен, пропускаем его установку${NC}"
fi

# Останавливаем старые контейнеры
sudo docker compose --env-file .env down --remove-orphans
mkdir -p ~/.vds
mkdir -p ~/.vds/proxy-config
mkdir -p ~/.vds/wg-easy

# Telegram Proxy
echo -e "${YELLOW}Подготовка MT Proxy${NC}"
PORT="484"
FAKE_DOMAIN="gosuslugi.ru"

if [ -f .env ]; then
	echo "$🛠️ Найден файл .env"
	source .env
fi

echo "🚀 Запуск MTProto прокси с Fake TLS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "📌 Используем домен: ${BLUE}${FAKE_DOMAIN}${NC}"

if [[ -z "$TG_PROXY_SECRET" ]]; then

	echo -n "🔑 Генерация Fake TLS секрета... "

	DOMAIN_HEX=$(echo -n $FAKE_DOMAIN | xxd -ps | tr -d '\n')
	echo -e "\n   Hex домена: ${DOMAIN_HEX}"

	DOMAIN_LEN=${#DOMAIN_HEX}
	NEEDED=$((30 - DOMAIN_LEN))
	RANDOM_HEX=$(openssl rand -hex 15 | cut -c1-$NEEDED)

	TG_PROXY_SECRET="ee${DOMAIN_HEX}${RANDOM_HEX}"

	echo -e "   Случайное дополнение: ${RANDOM_HEX}"
	echo -e "   Секрет: ${YELLOW}${TG_PROXY_SECRET}${NC}"
	echo "   Длина: ${#TG_PROXY_SECRET} символов"
fi
LINK="tg://proxy?server=${EXTERNAL_IP}&port=${PORT}&secret=${TG_PROXY_SECRET}"
LINK_HTTP="https://t.me/proxy?server=${EXTERNAL_IP}&port=${PORT}&secret=${TG_PROXY_SECRET}"

# Создаём .env
cat > .env << EOF
EXTERNAL_IP="${EXTERNAL_IP}"
WG_PANEL_PASSWORD="${WG_PANEL_PASSWORD}"
PORT="${PORT}"
TG_PROXY_SECRET="${TG_PROXY_SECRET}"
EOF

# Проверяем, свободен ли порт
echo -n "🔍 Проверка порта ${PORT}... "
if ss -tuln | grep -q ":${PORT} "; then
	echo -e "${RED}Порт занят: ${NC}"
	exit 1
else
	echo -e "${GREEN}✅ УСПЕШНО${NC}"
fi

# Запускаем docker compose
echo -n "📦 Запуск docker compose... "
sudo docker compose --env-file .env up -d

sleep 3

if sudo docker compose ps --format json | grep -q "wg-easy" && sudo docker compose ps --format json | grep -q "mtproto-proxy"; then

	echo -e "${GREEN}✅ УСПЕШНО${NC}"
	echo "✅ Конфигурация сохранена в .env"
	echo ""
	echo "📋 Логи контейнеров:"
	sudo docker compose logs --tail 5

else
	echo -e "${RED}❌ ОШИБКА${NC}"
	sudo docker compose logs --tail 5
	exit 1
fi


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Скрипт завершил свою работу!"
echo ""
echo "🔗 Ссылка для Telegram (IPv4):"
echo -e "${GREEN}${LINK}${NC}"
echo -e "${GREEN}${LINK_HTTP}${NC}"
echo ""
echo "🔗 Адрес панели wg-easy:"
echo -e "${GREEN}http://${EXTERNAL_IP}:51821/${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
