#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# Проверка цветов ДО перенаправления
if [[ -t 1 ]]; then
    USE_COLORS=true
else
    USE_COLORS=false
fi

# Логирование
LOGFILE="/var/log/vps_audit_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# Cleanup
YABS_TMP=""
cleanup() {
    [[ -n "$YABS_TMP" ]] && [[ -f "$YABS_TMP" ]] && rm -f "$YABS_TMP"
}
trap cleanup EXIT ERR INT TERM

# Цвета
if [[ "$USE_COLORS" == true ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    CYAN=$'\033[0;36m'
    NC=$'\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Требуется root${NC}"
   exit 1
fi

echo -e "${YELLOW}====================================================${NC}"
echo -e "${YELLOW}                   🔒 VPS AUDIT                    ${NC}"
echo -e "${YELLOW}====================================================${NC}"
echo -e "📄 Лог: $LOGFILE"

# Зависимости
echo -ne "🛠  Проверка... "

PACKAGES=(ethtool tcpdump curl)

install_package() {
    local pkg=$1
    if command -v apt-get &> /dev/null; then
        apt-get install -y "$pkg" >/dev/null 2>&1
    elif command -v dnf &> /dev/null; then
        dnf install -y "$pkg" >/dev/null 2>&1
    elif command -v yum &> /dev/null; then
        yum install -y "$pkg" >/dev/null 2>&1
    else
        return 1
    fi
}

MISSING_PKGS=()
INSTALLED=()
FAILED=()

for pkg in "${PACKAGES[@]}"; do
    command -v "$pkg" &> /dev/null || MISSING_PKGS+=("$pkg")
done

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Установка: ${MISSING_PKGS[*]}...${NC}"
    
    for pkg in "${MISSING_PKGS[@]}"; do
        echo -ne "  • $pkg... "
        if install_package "$pkg"; then
            echo -e "${GREEN}OK${NC}"
            INSTALLED+=("$pkg")
        else
            echo -e "${RED}FAIL${NC}"
            FAILED+=("$pkg")
        fi
    done
    
    [[ ${#INSTALLED[@]} -gt 0 ]] && echo -e "${GREEN}✅ Установлено: ${INSTALLED[*]}${NC}"
    [[ ${#FAILED[@]} -gt 0 ]] && echo -e "${YELLOW}⚠️  Не удалось: ${FAILED[*]}${NC}"
else
    echo -e "${GREEN}OK${NC}"
fi

# Сетевой интерфейс
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
[[ -z "$IFACE" ]] && IFACE="lo"

# Система
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   📋 СИСТЕМА${NC}"

KERNEL=$(uname -r)
echo -e "🐧 Kernel: ${GREEN}$KERNEL${NC}"

if [[ -f /etc/os-release ]]; then
    OS_NAME=$(grep "^PRETTY_NAME" /etc/os-release | cut -d= -f2 | tr -d '"')
    echo -e "💻 ОС: ${GREEN}$OS_NAME${NC}"
fi

VIRT=$(systemd-detect-virt 2>/dev/null || echo "unknown")
if [[ "$VIRT" =~ ^(kvm|vmware|xen|microsoft)$ ]]; then
    echo -e "🖥  Виртуализация: ${GREEN}$VIRT${NC}"
else
    echo -e "🖥  Виртуализация: ${RED}$VIRT${NC}"
fi

# Ресурсы
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   💾 РЕСУРСЫ${NC}"

MEM_INFO=$(free -h | grep "^Mem:")
TOTAL=$(echo "$MEM_INFO" | awk '{print $2}')
USED=$(echo "$MEM_INFO" | awk '{print $3}')
echo -e "🧠 RAM: ${GREEN}$USED / $TOTAL${NC}"

# Swap
if swapon --show &>/dev/null; then
    SWAP_SIZE=$(free -h | awk '/^Swap:/{print $2}')
    SWAP_BYTES=$(free -b | awk '/^Swap:/{print $2}')
    if [[ "$SWAP_BYTES" -gt 0 ]]; then
        echo -e "💤 Swap: ${GREEN}$SWAP_SIZE${NC}"
    else
        echo -e "💤 Swap: ${YELLOW}$SWAP_SIZE (не используется)${NC}"
    fi
else
    echo -e "💤 Swap: ${YELLOW}НЕ НАСТРОЕН${NC}"
fi

# OOM Killer - исправлено
OOM_COUNT=$(dmesg 2>/dev/null | grep -c "killed process" || echo "0")
OOM_COUNT=$(echo "$OOM_COUNT" | tr -d '\n' | xargs)
if [[ -n "$OOM_COUNT" ]] && [[ "$OOM_COUNT" -gt 0 ]] 2>/dev/null; then
    echo -e "☠️  OOM Killer: ${RED}Найдено $OOM_COUNT событий!${NC}"
else
    echo -e "☠️  OOM Killer: ${GREEN}Чисто${NC}"
fi

# CPU
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   ⚡ CPU${NC}"

CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)
CPU_CORES=$(nproc 2>/dev/null || grep -c processor /proc/cpuinfo)
echo -e "🔧 CPU: ${GREEN}$CPU_MODEL${NC}"
echo -e "🧮 Ядра: ${GREEN}$CPU_CORES${NC}"

# CPU Governor
GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")
if [[ "$GOVERNOR" != "N/A" ]]; then
    if [[ "$GOVERNOR" == "performance" ]]; then
        echo -e "🎚  Governor: ${GREEN}$GOVERNOR${NC}"
    else
        echo -e "🎚  Governor: ${YELLOW}$GOVERNOR (Рекомендуется: performance)${NC}"
    fi
fi

# Диски
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   💿 ДИСКИ${NC}"

df -h / | awk 'NR==2{printf "📂 Root: \033[0;32m%s / %s (%s)\033[0m\n", $3, $2, $5}'

ROOT_DEV=$(lsblk -no PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null | head -1)
if [[ -n "$ROOT_DEV" ]] && [[ -f "/sys/block/$ROOT_DEV/queue/scheduler" ]]; then
    SCHEDULER=$(grep -o '\[.*\]' "/sys/block/$ROOT_DEV/queue/scheduler" | tr -d '[]')
    echo -e "⚙️  I/O: ${GREEN}$SCHEDULER${NC}"
fi

# Сеть
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🌐 СЕТЬ ($IFACE)${NC}"

# IPv4
IPV4=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
echo -e "🔌 IPv4: ${GREEN}$IPV4${NC}"

# IPv6 - исправлено с отключением set -e
set +e
IPV6=$(ip -6 addr show "$IFACE" scope global 2>/dev/null | grep -oP 'inet6 \K[^/]+' | head -1)
if [[ -n "$IPV6" ]]; then
    echo -e "🌍 IPv6: ${GREEN}$IPV6${NC}"
    if ping -6 -c 1 -W 2 google.com &>/dev/null; then
        echo -e "   └─ Connectivity: ${GREEN}OK${NC}"
    else
        echo -e "   └─ Connectivity: ${RED}НЕТ СВЯЗИ${NC}"
    fi
else
    echo -e "🌍 IPv6: ${YELLOW}Не настроен${NC}"
fi
set -e

KERNEL_VER=$(uname -r | cut -d. -f1-2)
TCP_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")

if awk "BEGIN {exit !($KERNEL_VER >= 4.9)}"; then
    [[ "$TCP_CC" == "bbr" ]] && echo -e "🚀 Congestion: ${GREEN}BBR${NC}" || echo -e "🚀 Congestion: ${YELLOW}$TCP_CC (BBR доступен)${NC}"
else
    echo -e "🚀 Congestion: ${YELLOW}$TCP_CC (kernel < 4.9)${NC}"
fi

if command -v ethtool &> /dev/null; then
    RX_CUR=$(ethtool -g "$IFACE" 2>/dev/null | grep -A5 "Current" | grep "RX:" | awk '{print $2}')
    if [[ -n "$RX_CUR" ]]; then
        [[ "$RX_CUR" -lt 256 ]] && COLOR=$RED || COLOR=$GREEN
        echo -e "🌊 RX Buffer: ${COLOR}$RX_CUR${NC}"
    fi
else
    echo -e "🌊 RX Buffer: ${YELLOW}ethtool недоступен${NC}"
fi

echo -ne "⏱  DNS: "
if timeout 2 getent hosts google.com &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Время и NTP
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🕐 ВРЕМЯ И NTP${NC}"

TZ_INFO=$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}' || echo "unknown")
NTP_SYNC=$(timedatectl 2>/dev/null | grep -i "synchronized" | awk '{print $NF}' || echo "unknown")
echo -e "🌍 Timezone: ${GREEN}$TZ_INFO${NC}"

if [[ "$NTP_SYNC" == "yes" ]]; then
    echo -e "🔄 NTP Sync: ${GREEN}Синхронизировано${NC}"
else
    echo -e "🔄 NTP Sync: ${RED}НЕ синхронизировано!${NC}"
fi

# Безопасность
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🔒 БЕЗОПАСНОСТЬ${NC}"

# Firewall
echo -ne "🛡  Firewall: "
if command -v firewall-cmd &>/dev/null && systemctl is-active firewalld &>/dev/null; then
    echo -e "${GREEN}firewalld (активен)${NC}"
elif command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
    echo -e "${GREEN}ufw (активен)${NC}"
elif iptables -L -n 2>/dev/null | grep -qE "DROP|REJECT"; then
    echo -e "${GREEN}iptables (с правилами)${NC}"
elif nft list ruleset 2>/dev/null | grep -q "chain"; then
    echo -e "${GREEN}nftables (с правилами)${NC}"
else
    echo -e "${YELLOW}Не обнаружен или не настроен${NC}"
fi

# SELinux / AppArmor
if command -v getenforce &>/dev/null; then
    SELINUX=$(getenforce 2>/dev/null)
    if [[ "$SELINUX" == "Enforcing" ]]; then
        echo -e "🔐 SELinux: ${GREEN}$SELINUX${NC}"
    else
        echo -e "🔐 SELinux: ${YELLOW}$SELINUX${NC}"
    fi
elif command -v aa-status &>/dev/null; then
    if aa-enabled &>/dev/null; then
        echo -e "🔐 AppArmor: ${GREEN}Enabled${NC}"
    else
        echo -e "🔐 AppArmor: ${YELLOW}Disabled${NC}"
    fi
fi

# Entropy
ENTROPY=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
if [[ "$ENTROPY" -gt 1000 ]]; then
    echo -e "🎲 Entropy: ${GREEN}$ENTROPY (Достаточно)${NC}"
elif [[ "$ENTROPY" -gt 200 ]]; then
    echo -e "🎲 Entropy: ${YELLOW}$ENTROPY (Низковато)${NC}"
else
    echo -e "🎲 Entropy: ${RED}$ENTROPY (КРИТИЧЕСКИ МАЛО!)${NC}"
fi

# Лимиты
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   📊 ЛИМИТЫ СИСТЕМЫ${NC}"

NOFILE_SOFT=$(ulimit -Sn 2>/dev/null || echo "N/A")
NOFILE_HARD=$(ulimit -Hn 2>/dev/null || echo "N/A")
if [[ "$NOFILE_SOFT" != "N/A" ]] && [[ "$NOFILE_SOFT" -ge 65535 ]]; then
    echo -e "📁 Open Files: ${GREEN}$NOFILE_SOFT / $NOFILE_HARD${NC}"
else
    echo -e "📁 Open Files: ${YELLOW}$NOFILE_SOFT / $NOFILE_HARD (Рекомендуется >= 65535)${NC}"
fi

NPROC=$(ulimit -u 2>/dev/null || echo "N/A")
echo -e "⚙️  Max Processes: ${GREEN}$NPROC${NC}"

# Docker
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🐳 КОНТЕЙНЕРЫ${NC}"

if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
    if systemctl is-active docker &>/dev/null || pgrep -x dockerd &>/dev/null; then
        echo -e "🐳 Docker: ${GREEN}$DOCKER_VER (запущен)${NC}"
    else
        echo -e "🐳 Docker: ${YELLOW}$DOCKER_VER (не запущен)${NC}"
    fi
else
    echo -e "🐳 Docker: ${YELLOW}Не установлен${NC}"
fi

if grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo -e "   └─ ${YELLOW}Внутри Docker контейнера${NC}"
fi

# Мониторинг
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   🔊 МОНИТОРИНГ${NC}"

if command -v tcpdump &> /dev/null; then
    echo -ne "🕵️  Шум (3 сек)... "
    set +e
    NOISE=$(timeout --signal=KILL 3 tcpdump -i "$IFACE" -n "broadcast or multicast" 2>/dev/null | wc -l)
    TCPDUMP_EXIT=$?
    set -e
    
    if [[ $TCPDUMP_EXIT -eq 0 ]] || [[ $TCPDUMP_EXIT -eq 124 ]] || [[ $TCPDUMP_EXIT -eq 137 ]]; then
        PPS=$((NOISE / 3))
        [[ "$PPS" -gt 50 ]] && echo -e "${RED}$PPS pps (шторм)${NC}" || echo -e "${GREEN}$PPS pps${NC}"
    else
        echo -e "${YELLOW}Ошибка (код $TCPDUMP_EXIT)${NC}"
    fi
else
    echo -e "🕵️  Шум: ${YELLOW}tcpdump недоступен${NC}"
fi

# Порты - базовые
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   📬 ДОСТУПНОСТЬ (базовые порты)${NC}"

check_port() {
    timeout 2 bash -c "echo > /dev/tcp/$1/$2" 2>/dev/null && echo -e "   $3 ($2): ${GREEN}ОТКРЫТ${NC}" || echo -e "   $3 ($2): ${RED}ЗАКРЫТ${NC}"
}
check_port "google.com" 80 "HTTP"
check_port "google.com" 443 "HTTPS"

# SMTP порты
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   📧 SMTP ПОРТЫ (исходящие)${NC}"

check_smtp_outbound() {
    local host=$1
    local port=$2
    local name=$3
    
    if timeout 3 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "   ✅ $name ($port): ${GREEN}ДОСТУПЕН${NC}"
    else
        echo -e "   ❌ $name ($port): ${RED}ЗАБЛОКИРОВАН${NC}"
    fi
}

set +e

echo -e "${YELLOW}Проверка на Gmail:${NC}"
check_smtp_outbound "smtp.gmail.com" 25 "SMTP"
check_smtp_outbound "smtp.gmail.com" 465 "SMTPS"

echo -e "\n${YELLOW}Проверка на Mail.ru:${NC}"
check_smtp_outbound "smtp.mail.ru" 25 "SMTP"
check_smtp_outbound "smtp.mail.ru" 465 "SMTPS"

set -e

# Входящие порты
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}   📥 ВХОДЯЩИЕ ПОРТЫ (inbound)${NC}"

echo -e "${YELLOW}⚠️  Для проверки входящих портов используйте:${NC}"
echo -e "   • https://www.yougetsignal.com/tools/open-ports/"
echo -e "   • https://canyouseeme.org/"
echo -e "   • nmap -p 25,465 ВАШ_IP (с внешнего сервера)"

EXT_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "неизвестен")
echo -e "\n${CYAN}Ваш внешний IPv4: ${GREEN}$EXT_IP${NC}"

# Benchmark
if command -v curl &> /dev/null; then
    echo -e "\n${YELLOW}====================================================${NC}"
    echo -e "${YELLOW}                   🚀 BENCHMARK                    ${NC}"
    echo -e "${YELLOW}====================================================${NC}"

    read -p "Запустить YABS? (y/N): " -n 1 -r USER_REPLY < /dev/tty || true
    echo

    if [[ "$USER_REPLY" =~ ^[Yy]$ ]]; then
        YABS_TMP=$(mktemp)
        echo -e "📥 Скачивание..."
        
        if curl -sL https://yabs.sh -o "$YABS_TMP" 2>/dev/null && [[ -s "$YABS_TMP" ]]; then
            if bash -n "$YABS_TMP" 2>/dev/null; then
                echo -e "✅ Запуск...\n"
                bash "$YABS_TMP"
            else
                echo -e "${RED}❌ Невалидный скрипт${NC}"
            fi
        else
            echo -e "${RED}❌ Ошибка скачивания${NC}"
        fi
    else
        echo -e "⏹️  Пропущено"
    fi
fi

echo -e "\n${GREEN}✅ Готово${NC}"
