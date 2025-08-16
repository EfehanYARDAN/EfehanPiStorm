#!/bin/bash
set -euo pipefail

# 🔧 Ayarlar
SSID="Efehan Raspberry Pi 4B"
PASSWORD="E123456*e"
VNC_PASSWORD="raspberry"
LOGFILE="/var/log/otohotspot.log"
SCRIPT_PATH="/root/otohotspot.sh"
SERVICE_PATH="/etc/systemd/system/otohotspot.service"
STATIC_IP="192.168.50.1/24"

echo "[INFO] Kurulum başlatılıyor..." | tee -a "$LOGFILE"

# 🛡️ Root kontrolü
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Root yetkisi gerekli!" | tee -a "$LOGFILE"
  exit 1
fi

# 📦 Gerekli paketler
apt-get update
apt-get install -y network-manager x11vnc wireshark aircrack-ng bettercap

# 👥 Kullanıcıyı wireshark grubuna ekle
usermod -aG wireshark pi || true

# 🧩 Ana script oluştur
cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash
set -euo pipefail

SSID="$SSID"
PASSWORD="$PASSWORD"
VNC_PASSWORD="$VNC_PASSWORD"
LOGFILE="$LOGFILE"
STATIC_IP="$STATIC_IP"

echo "[INFO] Servis başlatılıyor..." | tee -a "\$LOGFILE"

# 🔌 Hotspot kurulumu
nmcli connection delete "\$SSID" || true
nmcli connection add type wifi ifname wlan0 con-name "\$SSID" autoconnect yes ssid "\$SSID"
nmcli connection modify "\$SSID" 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
nmcli connection modify "\$SSID" ipv4.addresses "\$STATIC_IP"
nmcli connection modify "\$SSID" ipv4.method shared
nmcli connection modify "\$SSID" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "\$PASSWORD"
nmcli connection up "\$SSID"

echo "[INFO] Hotspot açıldı: \$SSID (\$STATIC_IP)" | tee -a "\$LOGFILE"

# 🖥️ VNC başlat
x11vnc -forever -usepw -passwd "\$VNC_PASSWORD" -display :0 &
echo "[INFO] VNC başlatıldı" | tee -a "\$LOGFILE"

# 🧪 Bettercap başlat
nohup bettercap -iface wlan0 > /var/log/bettercap.log 2>&1 &
echo "[INFO] Bettercap çalışıyor (wlan0)" | tee -a "\$LOGFILE"

# 📡 Aircrack-ng monitor mod başlat
airmon-ng start wlan0 || true
echo "[INFO] Aircrack-ng monitor mod aktif (wlan0mon)" | tee -a "\$LOGFILE"

# 🔍 Wireshark hazır
echo "[INFO] Wireshark GUI ile kullanılabilir" | tee -a "\$LOGFILE"

echo "[SUCCESS] Tüm servisler çalışıyor" | tee -a "\$LOGFILE"
EOF

chmod +x "$SCRIPT_PATH"

# 🧩 Systemd servisi oluştur
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Raspberry Pi Oto Hotspot, VNC ve Ağ Araçları Servisi
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $SCRIPT_PATH
Restart=on-failure
StandardOutput=append:$LOGFILE
StandardError=append:$LOGFILE

[Install]
WantedBy=multi-user.target
EOF

# 🔄 Servisi aktif et
systemctl daemon-reexec
systemctl enable otohotspot.service
systemctl start otohotspot.service

echo "[✅] Kurulum tamamlandı. Servis aktif. IP: $STATIC_IP" | tee -a "$LOGFILE"
