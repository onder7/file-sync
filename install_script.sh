#!/bin/bash
# Ubuntu Server Dosya Senkronizasyon Sistemi Kurulum Scripti
# Bu script sistemi otomatik olarak kurar ve yapılandırır

set -e  # Hata durumunda çık

echo "🚀 Ubuntu Server Dosya Senkronizasyon Sistemi Kurulumu Başlıyor..."
echo "=================================================="

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonksiyonlar
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Root kontrolü
if [[ $EUID -eq 0 ]]; then
   log_error "Bu script root kullanıcısı ile çalıştırılmamalı"
   echo "Lütfen normal kullanıcı ile çalıştırın (sudo otomatik kullanılacak)"
   exit 1
fi

# Ubuntu kontrolü
if ! grep -q "Ubuntu" /etc/os-release; then
    log_warning "Bu script Ubuntu için optimize edilmiştir"
    read -p "Devam etmek istiyor musunuz? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Sistem güncellemesi
log_info "Sistem paketleri güncelleniyor..."
sudo apt update && sudo apt upgrade -y

# Gerekli paketlerin kurulumu
log_info "Gerekli sistem paketleri kuruluyor..."
PACKAGES=(
    "python3"
    "python3-pip"
    "python3-venv"
    "smbclient"
    "cifs-utils"
    "ftp"
    "lftp"
    "rsync"
    "openssh-client"
    "nginx"
    "supervisor"
    "git"
    "curl"
    "wget"
    "htop"
    "tree"
)

for package in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        log_success "$package zaten yüklü"
    else
        log_info "$package kuruluyor..."
        sudo apt install -y "$package"
        log_success "$package kuruldu"
    fi
done

# Uygulama dizini oluştur
APP_DIR="/opt/file-sync"
log_info "Uygulama dizini oluşturuluyor: $APP_DIR"
sudo mkdir -p "$APP_DIR"
sudo chown $USER:$USER "$APP_DIR"

# Python sanal ortam oluştur
log_info "Python sanal ortamı oluşturuluyor..."
cd "$APP_DIR"
python3 -m venv venv
source venv/bin/activate

# Python bağımlılıklarını yükle
log_info "Python paketleri kuruluyor..."
cat > requirements.txt << EOF
Flask==2.3.3
Flask-CORS==4.0.0
paramiko==3.3.1
requests==2.31.0
schedule==1.2.0
watchdog==3.0.0
psutil==5.9.5
gunicorn==21.2.0
EOF

pip install -r requirements.txt
log_success "Python paketleri kuruldu"

# Mount dizinleri oluştur
log_info "Mount dizinleri oluşturuluyor..."
sudo mkdir -p /mnt/smb
sudo mkdir -p /mnt/ftp
sudo chmod 755 /mnt/smb /mnt/ftp

# Sudo kuralları ekle (mount/umount için)
log_info "Sudo kuralları yapılandırılıyor..."
SUDO_RULES="/etc/sudoers.d/file-sync"
sudo tee "$SUDO_RULES" > /dev/null << EOF
# File Sync Uygulaması için gerekli sudo kuralları
$USER ALL=(ALL) NOPASSWD: /bin/mount
$USER ALL=(ALL) NOPASSWD: /bin/umount
$USER ALL=(ALL) NOPASSWD: /usr/bin/rsync
$USER ALL=(ALL) NOPASSWD: /usr/bin/lftp
EOF

sudo chmod 440 "$SUDO_RULES"
log_success "Sudo kuralları eklendi"

# Systemd service dosyası oluştur
log_info "Systemd service oluşturuluyor..."
SERVICE_FILE="/etc/systemd/system/file-sync.service"
sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=File Synchronization Web Application
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 4 --bind 0.0.0.0:5000 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Nginx konfigürasyonu
log_info "Nginx yapılandırılıyor..."
NGINX_CONFIG="/etc/nginx/sites-available/file-sync"
sudo tee "$NGINX_CONFIG" > /dev/null << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket desteği
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Statik dosyalar için
    location /static/ {
        alias $APP_DIR/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Nginx site'ı etkinleştir
sudo ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Firewall ayarları
log_info "Firewall ayarları yapılandırılıyor..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 22    # SSH
    sudo ufw allow 80    # HTTP
    sudo ufw allow 443   # HTTPS
    sudo ufw allow 21    # FTP
    sudo ufw allow 445   # SMB
    sudo ufw allow 139   # NetBIOS
    log_success "UFW kuralları eklendi"
fi

# Servisleri başlat
log_info "Servisler başlatılıyor..."
sudo systemctl daemon-reload
sudo systemctl enable file-sync
sudo systemctl restart nginx
sudo systemctl enable nginx

# Uygulama dosyalarını kopyala
log_info "Uygulama dosyaları kopyalanıyor..."

# app.py dosyasını oluştur (Flask backend)
cat > app.py << 'EOF'
# Flask backend kodu buraya gelecek (artifact'tan kopyala)
# Bu dosya yukarıda oluşturulan Flask uygulamasını içerir
EOF

# index.html dosyasını oluştur
cat > index.html << 'EOF'
<!-- HTML frontend kodu buraya gelecek (artifact'tan kopyala) -->
<!-- Bu dosya yukarıda oluşturulan web arayüzünü içerir -->
EOF

# Log dizini oluştur
sudo mkdir -p /var/log/file-sync
sudo chown $USER:$USER /var/log/file-sync

# Konfigürasyon dosyası oluştur
log_info "Konfigürasyon dosyası oluşturuluyor..."
cat > config.json << EOF
{
    "app": {
        "host": "0.0.0.0",
        "port": 5000,
        "debug": false
    },
    "logging": {
        "level": "INFO",
        "file": "/var/log/file-sync/app.log",
        "max_size": "10MB",
        "backup_count": 5
    },
    "sync": {
        "default_options": {
            "bidirectional": true,
            "delete_files": false,
            "preserve_attributes": true,
            "compress_transfer": true
        },
        "retry_count": 3,
        "retry_delay": 5
    },
    "security": {
        "max_connections": 10,
        "timeout": 300,
        "allowed_hosts": ["*"]
    }
}
EOF

# Cron job ekle (günlük log temizliği için)
log_info "Cron job'ı ekleniyor..."
(crontab -l 2>/dev/null; echo "0 2 * * * find /var/log/file-sync -name '*.log' -mtime +30 -delete") | crontab -

# Başlangıç scripti oluştur
cat > start.sh << EOF
#!/bin/bash
cd "$APP_DIR"
source venv/bin/activate
python app.py
EOF
chmod +x start.sh

# Test scripti oluştur
cat > test.sh << EOF
#!/bin/bash
echo "🔍 Sistem testi başlatılıyor..."

# Servis durumu
echo "📊 Servis durumları:"
systemctl is-active file-sync
systemctl is-active nginx

# Port kontrolü
echo "🔌 Port kontrolü:"
netstat -tlnp | grep :80
netstat -tlnp | grep :5000

# Mount dizinleri
echo "📁 Mount dizinleri:"
ls -la /mnt/

# Python paketleri
echo "🐍 Python paketleri:"
source venv/bin/activate
pip list | grep -E "(Flask|paramiko)"

echo "✅ Test tamamlandı"
EOF
chmod +x test.sh

# Deaktivate virtual environment
deactivate

# Servisi başlat
log_info "File Sync servisi başlatılıyor..."
sudo systemctl start file-sync

# Durum kontrolü
sleep 3
if sudo systemctl is-active --quiet file-sync; then
    log_success "File Sync servisi başarıyla başlatıldı"
else
    log_error "File Sync servisi başlatılamadı"
    log_info "Logları kontrol edin: sudo journalctl -u file-sync -f"
fi

if sudo systemctl is-active --quiet nginx; then
    log_success "Nginx başarıyla çalışıyor"
else
    log_error "Nginx başlatılamadı"
fi

# Kurulum özeti
echo ""
echo "=================================================="
log_success "Kurulum tamamlandı! 🎉"
echo "=================================================="
echo ""
echo "📋 Kurulum Özeti:"
echo "• Uygulama dizini: $APP_DIR"
echo "• Web arayüzü: http://$(hostname -I | awk '{print $1}')"
echo "• API endpoint: http://$(hostname -I | awk '{print $1}'):5000/api"
echo "• Log dosyası: /var/log/file-sync/"
echo ""
echo "🔧 Yönetim Komutları:"
echo "• Servisi başlat: sudo systemctl start file-sync"
echo "• Servisi durdur: sudo systemctl stop file-sync"
echo "• Servis durumu: sudo systemctl status file-sync"
echo "• Logları görüntüle: sudo journalctl -u file-sync -f"
echo "• Test çalıştır: cd $APP_DIR && ./test.sh"
echo ""
echo "📚 Mount Komutları:"
echo "• SMB mount: sudo mount -t cifs //server/share /mnt/smb -o username=user"
echo "• SMB unmount: sudo umount /mnt/smb"
echo ""
echo "🌐 Web arayüzüne tarayıcınızdan erişebilirsiniz:"
echo "   http://$(hostname -I | awk '{print $1}')"
echo ""
log_warning "İlk kullanımdan önce SMB ve FTP bağlantı bilgilerinizi yapılandırın"
echo "=================================================="
