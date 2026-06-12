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

# Docker
if ! command -v docker &> /dev/null; then
	curl -fsSL https://get.docker.com -o get-docker.sh
	sudo sh get-docker.sh
else
    echo -e "${YELLOW}Docker установлен, пропускаем его установку${NC}"
fi

# Wireguard (wg-easy)
echo -e "${YELLOW}Устанавливаем wg-easy${NC}"
WG_EASY_NAME="wg-easy"
docker stop $WG_EASY_NAME >/dev/null 2>&1
docker rm $WG_EASY_NAME >/dev/null 2>&1
docker run -d \
	--name=$WG_EASY_NAME \
	-e WG_HOST=$EXTERNAL_IP \
	-e PASSWORD=$WG_PANEL_PASSWORD \
	-v ~/.wg-easy:/etc/wireguard \
	-p 51820:51820/udp \
	-p 51821:51821/tcp \
	--cap-add=NET_ADMIN \
	--cap-add=SYS_MODULE \
	--sysctl="net.ipv4.conf.all.src_valid_mark=1" \
	--sysctl="net.ipv4.ip_forward=1" \
	--sysctl="net.ipv4.conf.all.rp_filter=0" \
	--restart unless-stopped \
	weejewel/wg-easy

echo -e "${GREEN}wg-easy успешно установлен${NC}"
echo -e "Адрес панели wg-easy:  ${GREEN}https:/${EXTERNAL_IP}:51821/${NC}"
	
#Telegram Proxy (telegrammessenger/proxy)
echo -e "${YELLOW}Устанавливаем MT Proxy${NC}"
MT_PROXY_NAME="mtproto-proxy"
PORT="484"
FAKE_DOMAIN="gosuslugi.ru"  # Фиксированный домен для Fake TLS

if [ -f ~/mtproto_config.txt ]; then
	source ~/mtproto_config.txt
fi

echo "🚀 Запуск MTProto прокси с Fake TLS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "📌 Используем домен: ${BLUE}${FAKE_DOMAIN}${NC}"

if [[ -z "$SECRET" ]]; then

	echo -n "🔑 Генерация Fake TLS секрета... "

	DOMAIN_HEX=$(echo -n $FAKE_DOMAIN | xxd -ps | tr -d '\n')
	echo -e "\n   Hex домена: ${DOMAIN_HEX}"

	# Дополняем случайными символами до 30 символов
	DOMAIN_LEN=${#DOMAIN_HEX}
	NEEDED=$((30 - DOMAIN_LEN))
	RANDOM_HEX=$(openssl rand -hex 15 | cut -c1-$NEEDED)

	SECRET="ee${DOMAIN_HEX}${RANDOM_HEX}"

	echo -e "   Случайное дополнение: ${RANDOM_HEX}"
	echo -e "   Секрет: ${YELLOW}${SECRET}${NC}"
	echo "   Длина: ${#SECRET} символов"
fi
LINK="tg://proxy?server=${EXTERNAL_IP}&port=${PORT}&secret=${SECRET}"

# Останавливаем старый контейнер, если есть
echo -n "🛑 Остановка старого контейнера... "
sudo docker stop ${MT_PROXY_NAME} >/dev/null 2>&1
sudo docker rm ${MT_PROXY_NAME} >/dev/null 2>&1
echo -e "${GREEN}✅ УСПЕШНО${NC}"

# Проверяем, свободен ли порт
echo -n "🔍 Проверка порта ${PORT}... "
if ss -tuln | grep -q ":${PORT} "; then
	echo -e "${RED}Порт занят: ${NC}"
	exit 1
else
	echo -e "${GREEN}✅ УСПЕШНО${NC}"
fi

# Запускаем официальный прокси от Telegram
echo -n "📦 Запуск контейнера... "
sudo docker run -d \
	--name ${MT_PROXY_NAME} \
	--restart unless-stopped \
	-p ${PORT}:443 \
	-v ~/.proxy-config:/data \
	-e SECRET="${SECRET}" \
	telegrammessenger/proxy > /dev/null 2>&1

# Проверяем результат
sleep 3
if sudo docker ps | grep -q ${MT_PROXY_NAME}; then
	SERVER_IP=$(curl -s ifconfig.me)
	
	echo -e "${GREEN}✅ УСПЕШНО${NC}"
	echo ""
	echo "📊 ИНФОРМАЦИЯ ДЛЯ ПОДКЛЮЧЕНИЯ:"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "🌐 Сервер: ${EXTERNAL_IP}"
	echo "🔌 Порт: ${PORT}"
	echo "🔑 Секрет: ${SECRET}"
	echo "🌐 Fake TLS домен: ${FAKE_DOMAIN}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "🔗 Ссылка для Telegram (IPv4):"
	echo -e "${GREEN}${LINK}${NC}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	
	# Сохраняем конфигурацию
	cat > ~/mtproto_config.txt << EOF
EXTERNAL_IP="${EXTERNAL_IP}"
PORT="${PORT}"
SECRET="${SECRET}"
FAKE_DOMAIN="${FAKE_DOMAIN}"
LINK="${LINK}"
EOF
	echo "✅ Конфигурация сохранена в ~/mtproto_config.txt"
	
	# Показываем последние логи
	echo ""
	echo "📋 Логи контейнера:"
	sudo docker logs --tail 5 ${MT_PROXY_NAME}
else
	echo -e "${RED}❌ ОШИБКА${NC}"
	sudo docker logs ${MT_PROXY_NAME}
fi


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Скрипт завершил свою работу!"
echo ""
echo "🔗 Ссылка для Telegram (IPv4):"
echo -e "${GREEN}${LINK}${NC}"
echo ""
echo "🔗 Адрес панели wg-easy:"
echo -e "${GREEN}http://${EXTERNAL_IP}:51821/${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"