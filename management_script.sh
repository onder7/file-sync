#!/bin/bash
# File Sync Sistem Yönetim Scripti
# Bu script sistemin yönetimi için kullanılır

APP_DIR="/opt/file-sync"
SERVICE_NAME="file-sync"

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fonksiyonlar
show_header() {
    clear
    echo -e "${CYAN}"
    echo "=================================================="
    echo "🔄 File Sync Sistem Yönetim Paneli"
    echo "=================================================="
    echo -e "${NC}"
}

show_status() {
    echo -e "${BLUE}📊 Sistem Durumu:${NC}"
    echo "===================="
    
    # Servis durumu
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "🟢 File Sync Servisi: ${GREEN}Çalışıyor${NC}"
    else
        echo -e "🔴 File Sync Servisi: ${RED}Durmuş${NC}"
    fi
    
    if systemctl is-active --quiet nginx; then
        echo -e "🟢 Nginx Web Sunucusu: ${GREEN}Çalışıyor${NC}"
    else
        echo -e "🔴 Nginx Web Sunucusu: ${RED}Durmuş${NC}"
    fi
    
    # Port kontrolü
    echo ""
    echo -e "${BLUE}🔌 Port Durumu:${NC}"
    if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        echo -e "🟢 Port 80 (HTTP): ${GREEN}Açık${NC}"
    else
        echo -e "🔴 Port 80 (HTTP): ${RED}Kapalı${NC}"
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q ":5000 "; then
        echo -e "🟢 Port 5000 (API): ${GREEN}Açık${NC}"
    else
        echo -e "🔴 Port 5000 (API): ${RED}Kapalı${NC}"
    fi
    
    # Mount durumu
    echo ""
    echo -e "${BLUE}📁 Mount Durumu:${NC}"
    if mount | grep -q "/mnt/smb"; then
        SMB_MOUNT=$(mount | grep "/mnt/smb" | awk '{print $1}')
        echo -e "🟢 SMB Mount: ${GREEN}$SMB_MOUNT${NC}"
    else
        echo -e "🔴 SMB Mount: ${RED}Bağlı değil${NC}"
    fi
    
    # Disk kullanımı
    echo ""
    echo -e "${BLUE}💾 Disk Kullanımı:${NC}"
    df -h /opt/file-sync 2>/dev/null | tail -1 | awk '{print "📊 " $5 " kullanılıyor (" $3 "/" $2 ")"}'
    
    # Bellek kullanımı
    echo ""
    echo -e "${BLUE}🧠 Bellek Kullanımı:${NC}"
    free -h | grep "Mem:" | awk '{print "📊 " $3 "/" $2 " kullanılıyor (" int($3/$2*100) "%)"}'
    
    echo ""
}

start_service() {
    echo -e "${YELLOW}🚀 Servis başlatılıyor...${NC}"
    sudo systemctl start $SERVICE_NAME
    sudo systemctl start nginx
    sleep 2
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✅ File Sync servisi başarıyla başlatıldı${NC}"
    else
        echo -e "${RED}❌ File Sync servisi başlatılamadı${NC}"
        echo "Log kontrolü için: sudo journalctl -u $SERVICE_NAME --no-pager -l"
    fi
}

stop_service() {
    echo -e "${YELLOW}⏹️ Servis durduruluyor...${NC}"
    sudo systemctl stop $SERVICE_NAME
    sleep 1
    echo -e "${GREEN}✅ File Sync servisi durduruldu${NC}"
}

restart_service() {
    echo -e "${YELLOW}🔄 Servis yeniden başlatılıyor...${NC}"
    sudo systemctl restart $SERVICE_NAME
    sudo systemctl restart nginx
    sleep 2
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✅ Servis başarıyla yeniden başlatıldı${NC}"
    else
        echo -e "${RED}❌ Servis yeniden başlatılamadı${NC}"
    fi
}

show_logs() {
    echo -e "${BLUE}📋 Son loglar (Çıkmak için Ctrl+C):${NC}"
    echo "=================================="
    sudo journalctl -u $SERVICE_NAME -f --no-pager
}

show_app_logs() {
    echo -e "${BLUE}📋 Uygulama logları:${NC}"
    echo "==================="
    if [ -f "/var/log/file-sync/app.log" ]; then
        tail -50 /var/log/file-sync/app.log
    else
        echo "Log dosyası bulunamadı"
    fi
}

backup_config() {
    echo -e "${YELLOW}💾 Konfigürasyon yedekleniyor...${NC}"
    BACKUP_DIR="/tmp/file-sync-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Konfigürasyon dosyalarını yedekle
    cp "$APP_DIR/config.json" "$BACKUP_DIR/" 2>/dev/null || echo "config.json bulunamadı"
    cp "/etc/nginx/sites-available/file-sync" "$BACKUP_DIR/nginx-config" 2>/dev/null
    cp "/etc/systemd/system/file-sync.service" "$BACKUP_DIR/systemd-service" 2>/dev/null
    
    echo -e "${GREEN}✅ Yedek oluşturuldu: $BACKUP_DIR${NC}"
    echo "İçerik:"
    ls -la "$BACKUP_DIR"
}

update_app() {
    echo -e "${YELLOW}🔄 Uygulama güncelleniyor...${NC}"
    cd "$APP_DIR"
    
    # Servisi durdur
    sudo systemctl stop $SERVICE_NAME
    
    # Virtual environment'ı aktifleştir
    source venv/bin/activate
    
    # Python paketlerini güncelle
    pip install --upgrade -r requirements.txt
    
    # Servisi başlat
    sudo systemctl start $SERVICE_NAME
    
    echo -e "${GREEN}✅ Güncelleme tamamlandı${NC}"
}

mount_smb() {
    echo -e "${YELLOW}📁 SMB Mount işlemi${NC}"
    echo "==================="
    
    read -p "SMB Server (örn: //192.168.1.100/share): " smb_server
    read -p "Kullanıcı adı: " username
    read -s -p "Şifre: " password
    echo
    
    echo "Mount ediliyor..."
    sudo mount -t cifs "$smb_server" /mnt/smb -o "username=$username,password=$password,uid=1000,gid=1000"
    
    if mount | grep -q "/mnt/smb"; then
        echo -e "${GREEN}✅ SMB başarıyla mount edildi${NC}"
        echo "İçerik:"
        ls -la /mnt/smb
    else
        echo -e "${RED}❌ SMB mount edilemedi${NC}"
    fi
}

unmount_smb() {
    echo -e "${YELLOW}📁 SMB Unmount işlemi${NC}"
    
    if mount | grep -q "/mnt/smb"; then
        sudo umount /mnt/smb
        echo -e "${GREEN}✅ SMB başarıyla unmount edildi${NC}"
    else
        echo -e "${YELLOW}⚠️ SMB zaten mount edilmemiş${NC}"
    fi
}

test_connections() {
    echo -e "${BLUE}🔍 Bağlantı testleri başlatılıyor...${NC}"
    echo "=================================="
    
    # Web arayüzü testi
    echo -n "🌐 Web arayüzü testi... "
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
        echo -e "${GREEN}✅ Başarılı${NC}"
    else
        echo -e "${RED}❌ Başarısız${NC}"
    fi
    
    # API testi
    echo -n "🔌 API testi... "
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/status | grep -q "200"; then
        echo -e "${GREEN}✅ Başarılı${NC}"
    else
        echo -e "${RED}❌ Başarısız${NC}"
    fi
    
    # SMB araçları testi
    echo -n "📁 SMB araçları... "
    if command -v smbclient &> /dev/null; then
        echo -e "${GREEN}✅ Yüklü${NC}"
    else
        echo -e "${RED}❌ Eksik${NC}"
    fi
    
    # FTP araçları testi
    echo -n "🌐 FTP araçları... "
    if command -v lftp &> /dev/null; then
        echo -e "${GREEN}✅ Yüklü${NC}"
    else
        echo -e "${RED}❌ Eksik${NC}"
    fi
    
    echo ""
}

system_info() {
    echo -e "${BLUE}ℹ️ Sistem Bilgileri:${NC}"
    echo "==================="
    echo "🖥️  Hostname: $(hostname)"
    echo "🌐 IP Adres: $(hostname -I | awk '{print $1}')"
    echo "💿 OS: $(lsb_release -d | cut -f2)"
    echo "🧠 CPU: $(nproc) çekirdek"
    echo "💾 RAM: $(free -h | grep Mem | awk '{print $2}')"
    echo "💽 Disk: $(df -h / | tail -1 | awk '{print $2}')"
    echo ""
    echo "📂 Uygulama dizini: $APP_DIR"
    echo "🔧 Python versiyonu: $(python3 --version)"
    echo "🌐 Web erişim: http://$(hostname -I | awk '{print $1}')"
    echo ""
}

cleanup_logs() {
    echo -e "${YELLOW}🧹 Log temizliği başlatılıyor...${NC}"
    
    # Systemd logları temizle (30 günden eski)
    sudo journalctl --vacuum-time=30d
    
    # Uygulama logları temizle
    if [ -d "/var/log/file-sync" ]; then
        sudo find /var/log/file-sync -name "*.log" -mtime +30 -delete
        echo -e "${GREEN}✅ Eski log dosyaları temizlendi${NC}"
    fi
    
    # Tmp dosyaları temizle
    sudo find /tmp -name "file-sync-*" -mtime +7 -delete 2>/dev/null || true
    
    echo -e "${GREEN}✅ Log temizliği tamamlandı${NC}"
}

show_menu() {
    show_header
    show_status
    
    echo -e "${PURPLE}🛠️ Yönetim Seçenekleri:${NC}"
    echo "======================"
    echo "1)  🚀 Servisi Başlat"
    echo "2)  ⏹️  Servisi Durdur"
    echo "3)  🔄 Servisi Yeniden Başlat"
    echo "4)  📋 Canlı Logları Göster"
    echo "5)  📄 Uygulama Logları"
    echo "6)  📁 SMB Mount"
    echo "7)  📂 SMB Unmount"
    echo "8)  🔍 Bağlantı Testleri"
    echo "9)  💾 Konfigürasyon Yedekle"
    echo "10) 🔄 Uygulamayı Güncelle"
    echo "11) ℹ️  Sistem Bilgileri"
    echo "12) 🧹 Log Temizliği"
    echo "13) 🌐 Web Arayüzünü Aç"
    echo "0)  ❌ Çıkış"
    echo ""
    echo -n "Seçiminizi yapın (0-13): "
}

open_web() {
    IP=$(hostname -I | awk '{print $1}')
    echo -e "${BLUE}🌐 Web arayüzü açılıyor...${NC}"
    echo "URL: http://$IP"
    
    # Varsayılan tarayıcıyı aç (desktop ortamında)
    if command -v xdg-open &> /dev/null; then
        xdg-open "http://$IP" &
    elif command -v firefox &> /dev/null; then
        firefox "http://$IP" &
    elif command -v google-chrome &> /dev/null; then
        google-chrome "http://$IP" &
    else
        echo "Tarayıcınızdan şu adresi ziyaret edin: http://$IP"
    fi
}

# Ana program döngüsü
while true; do
    show_menu
    read -r choice
    
    case $choice in
        1)
            start_service
            ;;
        2)
            stop_service
            ;;
        3)
            restart_service
            ;;
        4)
            show_logs
            ;;
        5)
            show_app_logs
            ;;
        6)
            mount_smb
            ;;
        7)
            unmount_smb
            ;;
        8)
            test_connections
            ;;
        9)
            backup_config
            ;;
        10)
            update_app
            ;;
        11)
            system_info
            ;;
        12)
            cleanup_logs
            ;;
        13)
            open_web
            ;;
        0)
            echo -e "${GREEN}👋 Güle güle!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Geçersiz seçim. Lütfen 0-13 arası bir sayı girin.${NC}"
            ;;
    esac
    
    echo ""
    echo -e "${YELLOW}Devam etmek için Enter tuşuna basın...${NC}"
    read -r
done
