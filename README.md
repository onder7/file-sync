# 🚀 Ubuntu Server Dosya Senkronizasyon Sistemi
## Hızlı Başlangıç Rehberi

### 📋 Sistem Gereksinimleri

- **İşletim Sistemi:** Ubuntu Server 20.04+ (diğer Linux dağıtımlarında da çalışır)
- **RAM:** Minimum 2GB (4GB önerilen)
- **Disk:** 10GB boş alan
- **Network:** SMB ve FTP sunucularına erişim
- **Yetkiler:** sudo erişimi

### ⚡ Tek Komut Kurulum

```bash
# Kurulum scriptini indir ve çalıştır
wget -O install.sh https://github.com/onder7/file-sync/main/install.sh
chmod +x install.sh
./install.sh
```

### 🔧 Manuel Kurulum Adımları

#### 1. Sistem Hazırlığı
```bash
# Sistem güncellemesi
sudo apt update && sudo apt upgrade -y

# Gerekli paketleri yükle
sudo apt install -y python3 python3-pip python3-venv smbclient cifs-utils ftp lftp rsync nginx supervisor
```

#### 2. Uygulama Kurulumu
```bash
# Uygulama dizini oluştur
sudo mkdir -p /opt/file-sync
sudo chown $USER:$USER /opt/file-sync
cd /opt/file-sync

# Python sanal ortam oluştur
python3 -m venv venv
source venv/bin/activate

# Bağımlılıkları yükle
pip install Flask Flask-CORS paramiko requests gunicorn
```

#### 3. Dosyaları Yerleştir
```bash
# Flask backend dosyasını kopyala (app.py)
# HTML frontend dosyasını kopyala (index.html)
# Konfigürasyon dosyasını oluştur (config.json)
```

#### 4. Sistem Servisi Oluştur
```bash
# Systemd service dosyası oluştur
sudo nano /etc/systemd/system/file-sync.service

# Servisi etkinleştir
sudo systemctl daemon-reload
sudo systemctl enable file-sync
sudo systemctl start file-sync
```

### 🌐 Web Arayüzü Erişimi

Kurulum tamamlandıktan sonra web arayüzüne şu adreslerden erişebilirsiniz:

- **HTTP:** `http://[SUNUCU-IP]`
- **Direkt API:** `http://[SUNUCU-IP]:5000`

### 📁 İlk Konfigürasyon

#### SMB/CIFS Bağlantısı
1. Web arayüzünde **SMB/CIFS Bağlantısı** paneline gidin
2. Sunucu bilgilerini girin:
   - **Sunucu Adresi:** `//192.168.1.100/paylaşım`
   - **Kullanıcı Adı:** SMB kullanıcı adınız
   - **Şifre:** SMB şifreniz
   - **Mount Noktası:** `/mnt/smb` (varsayılan)
3. **SMB Bağlan** butonuna tıklayın

#### FTP Bağlantısı
1. **FTP Bağlantısı** paneline gidin
2. FTP bilgilerini girin:
   - **FTP Sunucusu:** `192.168.1.200`
   - **Port:** `21` (FTP) veya `22` (SFTP)
   - **Protokol:** FTP/SFTP/FTPS
   - **Kullanıcı Adı:** FTP kullanıcı adınız
   - **Şifre:** FTP şifreniz
3. **FTP Bağlan** butonuna tıklayın

### ⚙️ Senkronizasyon Ayarları

#### Temel Seçenekler
- **✅ Çift Yönlü Senkronizasyon:** Her iki yönde dosya transferi
- **❌ Silinmiş Dosyaları Temizle:** Kaynak silindiğinde hedefte de sil
- **✅ Dosya Özniteliklerini Koru:** Tarih, izin gibi bilgileri koru
- **✅ Transfer Sıkıştırması:** Bandwidth tasarrufu için sıkıştır

#### Manuel Senkronizasyon
1. Her iki bağlantının da aktif olduğundan emin olun
2. Senkronizasyon seçeneklerini ayarlayın
3. **🔄 Senkronizasyonu Başlat** butonuna tıklayın
4. İlerlemeyi takip edin

#### Zamanlanmış Senkronizasyon
1. **⏰ Zamanlanmış Sync** butonuna tıklayın
2. Dakika cinsinden aralık girin (örn: 30)
3. Otomatik senkronizasyon başlar

### 🛠️ Sistem Yönetimi

#### Yönetim Scripti Kullanımı
```bash
cd /opt/file-sync
./manage.sh
```

#### Manuel Komutlar
```bash
# Servis kontrolü
sudo systemctl start file-sync    # Başlat
sudo systemctl stop file-sync     # Durdur
sudo systemctl restart file-sync  # Yeniden başlat
sudo systemctl status file-sync   # Durum

# Log kontrolü
sudo journalctl -u file-sync -f   # Canlı loglar
tail -f /var/log/file-sync/app.log # Uygulama logları

# Manuel mount/unmount
sudo mount -t cifs //server/share /mnt/smb -o username=user,password=pass
sudo umount /mnt/smb
```

### 🔍 Sorun Giderme

#### Sık Karşılaşılan Sorunlar

**🔴 SMB Bağlantı Sorunu**
```bash
# CIFS utilities kontrolü
sudo apt install cifs-utils

# Mount izinleri
sudo chmod 755 /mnt/smb

# SMB versiyonu belirt
sudo mount -t cifs //server/share /mnt/smb -o username=user,password=pass,vers=2.0
```

**🔴 FTP Bağlantı Sorunu**
```bash
# FTP araçları kontrolü
sudo apt install ftp lftp

# Firewall kontrolü
sudo ufw allow 21
sudo ufw allow 22

# Pasif mod testi
lftp -u username,password ftp://server
```

**🔴 Web Arayüzü Erişim Sorunu**
```bash
# Nginx kontrolü
sudo systemctl status nginx
sudo nginx -t

# Port kontrolü
netstat -tlnp | grep :80

# Firewall ayarları
sudo ufw allow 80
sudo ufw allow 443
```

**🔴 Servis Başlatma Sorunu**
```bash
# Python virtual environment kontrolü
cd /opt/file-sync
source venv/bin/activate
python -c "import flask; print('Flask çalışıyor')"

# İzin kontrolü
sudo chown -R $USER:$USER /opt/file-sync
chmod +x /opt/file-sync/app.py

# Bağımlılık kontrolü
pip install -r requirements.txt
```

#### Log Analizi
```bash
# Son 50 log satırı
sudo journalctl -u file-sync -n 50

# Hata logları
sudo journalctl -u file-sync -p err

# Belirli tarih aralığı
sudo journalctl -u file-sync --since "2024-01-01" --until "2024-01-02"
```

### 📊 Performans Optimizasyonu

#### Sistem Ayarları
```bash
# Dosya tanımlayıcı limitini artır
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Network buffer boyutları
echo "net.core.rmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

#### Uygulama Ayarları
```json
{
  "sync": {
    "parallel_transfers": 4,
    "chunk_size": "1MB",
    "retry_count": 3,
    "timeout": 300
  }
}
```

### 🔐 Güvenlik Önerileri

#### Sistem Güvenliği
```bash
# UFW firewall aktifleştir
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443

# SSH güvenlik ayarları
sudo nano /etc/ssh/sshd_config
# PasswordAuthentication no
# PubkeyAuthentication yes
```

#### Uygulama Güvenliği
- SMB/FTP şifrelerini güçlü tutun
- HTTPS kullanın (Let's Encrypt ile SSL)
- Düzenli güncellemeler yapın
- Log dosyalarını kontrol edin

### 📈 İzleme ve Bakım

#### Düzenli Kontroller
```bash
# Haftalık sistem kontrolü
./test.sh

# Aylık log temizliği
./manage.sh # Seçenek 12

# Güncelleme kontrolü
apt list --upgradable
```

#### Yedekleme
```bash
# Konfigürasyon yedekleme
./manage.sh # Seçenek 9

# Tam sistem yedekleme
sudo tar -czf /backup/file-sync-$(date +%Y%m%d).tar.gz /opt/file-sync
```

### 📞 Destek ve Katkı

- **Dokümantasyon:** `/opt/file-sync/docs/`
- **Log Dosyaları:** `/var/log/file-sync/`
- **Konfigürasyon:** `/opt/file-sync/config.json`
- **GitHub Issues:** Sorun bildirimi için
- **Wiki:** Detaylı dokümantasyon

### 🎉 Başarılı Kurulum Kontrolü

Kurulum başarılı ise:
- ✅ Web arayüzü açılıyor
- ✅ SMB bağlantısı kuruluyor
- ✅ FTP bağlantısı kuruluyor  
- ✅ Dosya senkronizasyonu çalışıyor
- ✅ Loglar düzgün kaydediliyor

**🎊 Tebrikler! Sistem kullanıma hazır!**
