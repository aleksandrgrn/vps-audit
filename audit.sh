#!/bin/bash

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}====================================================${NC}"
echo -e "${YELLOW}   🔍 УНИВЕРСАЛЬНЫЙ АУДИТ VPS (CentOS/Ubuntu/Rocky) ${NC}"
echo -e "${YELLOW}====================================================${NC}"

# --- 1. УМНАЯ УСТАНОВКА ЗАВИСИМОСТЕЙ ---
echo -ne "🛠  Проверка инструментов (ethtool, tcpdump, curl)... "

INSTALL_CMD=""
PACKAGES="ethtool tcpdump curl"

# Определение пакетного менеджера
if command -v apt-get &> /dev/null; then
    INSTALL_CMD="apt-get update -qq && apt-get install -y -qq $PACKAGES"
elif command -v dnf &> /dev/null; then
    INSTALL_CMD="dnf install -y -q $PACKAGES"
elif command -v yum &> /dev/null; then
    INSTALL_CMD="yum install -y -q $PACKAGES"
fi

# Проверяем, всё ли стоит, если нет — ставим
if ! command -v ethtool &> /dev/null || ! command -v tcpdump &> /dev/null || ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}Установка...${NC}"
    eval "$INSTALL_CMD > /dev/null 2>&1"
    if [ $? -ne 0 ]; then
        echo -e "${RED}ОШИБКА УСТАНОВКИ! Проверьте репозитории (особенно на CentOS 7).${NC}"
        # Не выходим, пробуем проверить что сможем
    else
        echo -e "${GREEN}Установлено.${NC}"
    fi
else
    echo -e "${GREEN}OK${NC}"
fi

# --- 2. ВИРТУАЛИЗАЦИЯ ---
VIRT=$(systemd-detect-virt 2>/dev/null || echo "unknown")
echo -ne "🖥  Виртуализация: "
if [[ "$VIRT" =~ ^(kvm|vmware|xen|microsoft)$ ]]; then
    echo -e "${GREEN}$VIRT (Подходит)${NC}"
else
    echo -e "${RED}$VIRT (ВНИМАНИЕ! Возможны проблемы с Docker/WG)${NC}"
fi

# --- 3. СЕТЕВОЙ БУФЕР (RX RING) ---
# Автоопределение интерфейса (берем тот, где default route)
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo -ne "🌊 RX Ring Buffer ($IFACE): "

if command -v ethtool &> /dev/null; then
    # Получаем текущее значение
    RX_CUR=$(ethtool -g $IFACE 2>/dev/null | grep -A 5 "Current hardware settings" | grep "RX:" | awk '{print $2}')
    # Получаем максимум
    RX_MAX=$(ethtool -g $IFACE 2>/dev/null | grep -A 5 "Pre-set maximums" | grep "RX:" | awk '{print $2}')
    
    # Если ethtool ничего не вернул (например, на virtio иногда бывает пусто или карта не умеет)
    if [[ -z "$RX_CUR" ]]; then
        echo -e "${YELLOW}Не удалось считать (Драйвер не отдает данные)${NC}"
    elif [[ "$RX_CUR" -lt 256 ]]; then
        echo -e "${RED}$RX_CUR (КРИТИЧЕСКИ МАЛО! Риск потерь)${NC} / Max: $RX_MAX"
    else
        echo -e "${GREEN}$RX_CUR (Норма)${NC} / Max: $RX_MAX"
    fi
else
    echo -e "${YELLOW}Нет ethtool${NC}"
fi

# --- 4. УРОВЕНЬ ШУМА (BROADCAST STORM) ---
echo -ne "🔊 Уровень шума (3 сек): "
if command -v tcpdump &> /dev/null; then
    NOISE=$(timeout 3 tcpdump -i $IFACE -n "broadcast or multicast" 2>/dev/null | wc -l)
    PPS=$((NOISE / 3))
    
    if [[ "$PPS" -gt 50 ]]; then
        echo -e "${RED}ГРЯЗНО! ~$PPS pps (Broadcast Storm)${NC}"
    elif [[ "$PPS" -gt 10 ]]; then
        echo -e "${YELLOW}Шумно (~$PPS pps)${NC}"
    else
        echo -e "${GREEN}Чисто (~$PPS pps)${NC}"
    fi
else
    echo -e "${YELLOW}Нет tcpdump${NC}"
fi

# --- 5. ПОРТЫ (MAIL / WEB) ---
echo -e "\n📬 Проверка портов (Firewall провайдера):"
check_port() {
    host=$1; port=$2; name=$3
    timeout 2 bash -c "</dev/tcp/$host/$port" 2>/dev/null
    if [ $? -eq 0 ]; then echo -e "   $name ($port): ${GREEN}ОТКРЫТ${NC}"; else echo -e "   $name ($port): ${RED}ЗАКРЫТ${NC}"; fi
}
# Используем bash /dev/tcp, работает везде, где есть bash
check_port "gmail-smtp-in.l.google.com" 25 "SMTP (25)"
check_port "smtp.gmail.com" 465 "SMTPS (465)"
check_port "google.com" 80 "HTTP (80)"
check_port "google.com" 443 "HTTPS (443)"

# --- 6. ЗАПУСК YABS ---
echo -e "\n${YELLOW}====================================================${NC}"
echo -e "   🚀 ЗАПУСК YABS (BENCHMARK)   "
echo -e "${YELLOW}====================================================${NC}"
sleep 2

if command -v curl &> /dev/null; then
    # YABS запускается. Флаги:
    # -i : пропустить тест сети (iperf) - сэконимит 10 мин (уберите флаг, если хотите проверить скорость)
    # curl -sL yabs.sh | bash -s -- -i
    
    # Полный тест:
    curl -sL yabs.sh | bash
else
    echo -e "${RED}Ошибка: curl не установлен, не могу скачать YABS.${NC}"
fi