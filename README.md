# 🔍 VPS Audit

Универсальный Bash-скрипт для быстрой диагностики VPS-серверов. Совместим с **Ubuntu/Debian** и **RHEL/CentOS/Rocky**.

## 🚀 Быстрый старт

```bash
curl -sL https://raw.githubusercontent.com/aleksandrgrn/vps-audit/main/audit.sh | bash
```

## 📋 Что проверяет

| Проверка | Описание |
|----------|----------|
| 🖥 Виртуализация | KVM/VMware/Xen — подходит ли для Docker/WireGuard |
| 🌊 RX Ring Buffer | Размер сетевого буфера (риск потери пакетов) |
| 🔊 Broadcast Storm | Уровень шума в сети (3 сек замер) |
| 📬 Порты | SMTP (25/465), HTTP (80), HTTPS (443) |
| 🚀 YABS Benchmark | Полный тест CPU/Disk/Network |

## ⚙️ Зависимости

Скрипт автоматически установит недостающие пакеты:
- `ethtool`
- `tcpdump`  
- `curl`

## 📄 Лицензия

[MIT](LICENSE)
