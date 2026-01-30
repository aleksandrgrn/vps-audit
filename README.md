# 🔍 VPS Audit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![One-liner](https://img.shields.io/badge/curl%20%7C%20bash-ready-brightgreen.svg)](https://raw.githubusercontent.com/aleksandrgrn/vps-audit/master/audit.sh)

Универсальный Bash-скрипт для быстрой диагностики VPS-серверов. Совместим с **Ubuntu/Debian** и **RHEL/CentOS/Rocky**.

![Пример вывода](assets/screenshot.png)

## 🚀 Быстрый старт

```bash
curl -sL https://is.gd/LLoGt2 | sudo bash
```

<details>
<summary>Альтернативная ссылка (полная)</summary>

```bash
curl -sL https://raw.githubusercontent.com/aleksandrgrn/vps-audit/master/audit.sh | sudo bash
```
</details>

## 📋 Что проверяет

| Категория | Проверки |
|-----------|----------|
| 📋 **Система** | Kernel, ОС, тип виртуализации (KVM/VMware/Xen) |
| 💾 **Ресурсы** | RAM, Swap, OOM Killer история |
| ⚡ **CPU** | Модель, ядра, CPU Governor |
| 💿 **Диски** | Использование /, I/O Scheduler |
| 🌐 **Сеть** | IPv4/IPv6, TCP BBR, RX Buffer, DNS |
| 🕐 **Время** | Timezone, NTP синхронизация |
| 🔒 **Безопасность** | Firewall, SELinux/AppArmor, Entropy |
| 📊 **Лимиты** | Open Files, Max Processes |
| 🐳 **Контейнеры** | Docker статус |
| 🔊 **Мониторинг** | Broadcast/Multicast шум (3 сек) |
| 📬 **Порты** | HTTP (80), HTTPS (443) |
| 📧 **SMTP** | Gmail и Mail.ru (25/465) — исходящие |
| 🚀 **Benchmark** | YABS (опционально) |

## ✨ Особенности

- 🔧 **Автоустановка зависимостей** — ethtool, tcpdump, curl
- 📄 **Логирование** — результаты сохраняются в `/var/log/vps_audit_*.log`
- 🛡️ **Strict mode** — `set -euo pipefail` для надёжности
- 🎨 **Цветной вывод** — с автоотключением при pipe

## ⚙️ Требования

- **Root-доступ** (для ethtool, tcpdump, dmesg)
- **Bash 4+**
- Поддерживаемые ОС: Ubuntu, Debian, CentOS, RHEL, Rocky, Alma

## 📄 Лицензия

[MIT](LICENSE)
