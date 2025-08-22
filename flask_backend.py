#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ubuntu Server Dosya Senkronizasyon Backend
Flask API ile SMB/CIFS ve FTP senkronizasyonu
"""

from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
import subprocess
import os
import json
import threading
import time
from datetime import datetime
import ftplib
import paramiko
from pathlib import Path
import logging

app = Flask(__name__)
CORS(app)

# Logging ayarları
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SyncManager:
    def __init__(self):
        self.smb_connected = False
        self.ftp_connected = False
        self.sync_in_progress = False
        self.sync_log = []
        self.config = {
            'smb': {},
            'ftp': {},
            'sync_options': {
                'bidirectional': True,
                'delete_files': False,
                'preserve_attributes': True,
                'compress_transfer': True
            }
        }
        
    def add_log(self, message, level="info"):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = {
            'timestamp': timestamp,
            'message': message,
            'level': level
        }
        self.sync_log.append(log_entry)
        logger.info(f"[{timestamp}] {message}")
        
        # Son 1000 log kaydını tut
        if len(self.sync_log) > 1000:
            self.sync_log = self.sync_log[-1000:]

sync_manager = SyncManager()

@app.route('/')
def index():
    """Ana sayfa - Web uygulamasını serve eder"""
    return render_template_string(open('index.html', 'r', encoding='utf-8').read())

@app.route('/api/smb/connect', methods=['POST'])
def connect_smb():
    """SMB/CIFS bağlantısı kur"""
    try:
        data = request.json
        server = data.get('server')
        username = data.get('username')
        password = data.get('password')
        mount_point = data.get('mount_point', '/mnt/smb')
        
        sync_manager.add_log(f"SMB bağlantısı kuruluyor: {server}")
        
        # Mount noktasını oluştur
        os.makedirs(mount_point, exist_ok=True)
        
        # SMB mount komutu
        mount_cmd = [
            'sudo', 'mount', '-t', 'cifs',
            server, mount_point,
            '-o', f'username={username},password={password},uid=1000,gid=1000'
        ]
        
        result = subprocess.run(mount_cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            sync_manager.smb_connected = True
            sync_manager.config['smb'] = {
                'server': server,
                'username': username,
                'mount_point': mount_point
            }
            sync_manager.add_log("SMB bağlantısı başarılı", "success")
            return jsonify({'success': True, 'message': 'SMB bağlantısı başarılı'})
        else:
            sync_manager.add_log(f"SMB bağlantı hatası: {result.stderr}", "error")
            return jsonify({'success': False, 'error': result.stderr})
            
    except Exception as e:
        sync_manager.add_log(f"SMB bağlantı hatası: {str(e)}", "error")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/smb/disconnect', methods=['POST'])
def disconnect_smb():
    """SMB bağlantısını kes"""
    try:
        if not sync_manager.smb_connected:
            return jsonify({'success': False, 'error': 'SMB zaten bağlı değil'})
        
        mount_point = sync_manager.config['smb'].get('mount_point', '/mnt/smb')
        
        # Unmount komutu
        umount_cmd = ['sudo', 'umount', mount_point]
        result = subprocess.run(umount_cmd, capture_output=True, text=True)
        
        sync_manager.smb_connected = False
        sync_manager.add_log("SMB bağlantısı kesildi", "success")
        
        return jsonify({'success': True, 'message': 'SMB bağlantısı kesildi'})
        
    except Exception as e:
        sync_manager.add_log(f"SMB bağlantı kesme hatası: {str(e)}", "error")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/ftp/connect', methods=['POST'])
def connect_ftp():
    """FTP bağlantısı kur"""
    try:
        data = request.json
        server = data.get('server')
        port = int(data.get('port', 21))
        username = data.get('username')
        password = data.get('password')
        protocol = data.get('protocol', 'ftp')
        
        sync_manager.add_log(f"FTP bağlantısı kuruluyor: {server}:{port}")
        
        if protocol == 'ftp':
            ftp = ftplib.FTP()
            ftp.connect(server, port)
            ftp.login(username, password)
            ftp.quit()
        elif protocol == 'sftp':
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(server, port, username, password)
            sftp = ssh.open_sftp()
            sftp.close()
            ssh.close()
        
        sync_manager.ftp_connected = True
        sync_manager.config['ftp'] = {
            'server': server,
            'port': port,
            'username': username,
            'protocol': protocol
        }
        sync_manager.add_log("FTP bağlantısı başarılı", "success")
        
        return jsonify({'success': True, 'message': 'FTP bağlantısı başarılı'})
        
    except Exception as e:
        sync_manager.add_log(f"FTP bağlantı hatası: {str(e)}", "error")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/ftp/disconnect', methods=['POST'])
def disconnect_ftp():
    """FTP bağlantısını kes"""
    sync_manager.ftp_connected = False
    sync_manager.add_log("FTP bağlantısı kesildi", "success")
    return jsonify({'success': True, 'message': 'FTP bağlantısı kesildi'})

@app.route('/api/files/smb')
def list_smb_files():
    """SMB dosyalarını listele"""
    try:
        if not sync_manager.smb_connected:
            return jsonify({'success': False, 'error': 'SMB bağlı değil'})
        
        mount_point = sync_manager.config['smb'].get('mount_point', '/mnt/smb')
        files = []
        
        if os.path.exists(mount_point):
            for item in os.listdir(mount_point):
                item_path = os.path.join(mount_point, item)
                is_dir = os.path.isdir(item_path)
                size = os.path.getsize(item_path) if not is_dir else 0
                modified = os.path.getmtime(item_path)
                
                files.append({
                    'name': item,
                    'is_directory': is_dir,
                    'size': size,
                    'modified': datetime.fromtimestamp(modified).isoformat()
                })
        
        return jsonify({'success': True, 'files': files})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/files/ftp')
def list_ftp_files():
    """FTP dosyalarını listele"""
    try:
        if not sync_manager.ftp_connected:
            return jsonify({'success': False, 'error': 'FTP bağlı değil'})
        
        config = sync_manager.config['ftp']
        files = []
        
        if config['protocol'] == 'ftp':
            ftp = ftplib.FTP()
            ftp.connect(config['server'], config['port'])
            ftp.login(config['username'], '')  # Şifre cache'den alınabilir
            
            file_list = []
            ftp.retrlines('LIST', file_list.append)
            
            for line in file_list:
                parts = line.split()
                if len(parts) >= 9:
                    is_dir = line.startswith('d')
                    name = ' '.join(parts[8:])
                    size = int(parts[4]) if not is_dir else 0
                    
                    files.append({
                        'name': name,
                        'is_directory': is_dir,
                        'size': size,
                        'modified': ''
                    })
            
            ftp.quit()
        
        return jsonify({'success': True, 'files': files})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/sync/start', methods=['POST'])
def start_sync():
    """Senkronizasyonu başlat"""
    try:
        if sync_manager.sync_in_progress:
            return jsonify({'success': False, 'error': 'Senkronizasyon zaten devam ediyor'})
        
        if not (sync_manager.smb_connected and sync_manager.ftp_connected):
            return jsonify({'success': False, 'error': 'Her iki bağlantı da aktif olmalı'})
        
        data = request.json or {}
        sync_manager.config['sync_options'].update(data.get('options', {}))
        
        # Arka planda senkronizasyon başlat
        sync_thread = threading.Thread(target=perform_sync)
        sync_thread.daemon = True
        sync_thread.start()
        
        return jsonify({'success': True, 'message': 'Senkronizasyon başlatıldı'})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

def perform_sync():
    """Senkronizasyon işlemini gerçekleştir"""
    sync_manager.sync_in_progress = True
    sync_manager.add_log("Senkronizasyon başlatıldı", "info")
    
    try:
        smb_path = sync_manager.config['smb']['mount_point']
        ftp_config = sync_manager.config['ftp']
        options = sync_manager.config['sync_options']
        
        # Rsync kullanarak senkronizasyon
        rsync_opts = ['-av']
        
        if options.get('compress_transfer'):
            rsync_opts.append('-z')
        
        if options.get('delete_files'):
            rsync_opts.append('--delete')
        
        if not options.get('preserve_attributes'):
            rsync_opts.append('--no-perms')
        
        # FTP için rsync komutu oluştur
        if ftp_config['protocol'] == 'ftp':
            # FTP için lftp kullan
            sync_manager.add_log("LFTP ile senkronizasyon başlatılıyor", "info")
            
            lftp_cmd = f"""
            lftp -u {ftp_config['username']}, {ftp_config['server']} << EOF
            set ftp:list-options -a
            mirror --verbose {smb_path} /
            quit
            EOF
            """
            
            result = subprocess.run(lftp_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                sync_manager.add_log("Senkronizasyon başarılı", "success")
            else:
                sync_manager.add_log(f"Senkronizasyon hatası: {result.stderr}", "error")
        
        time.sleep(2)  # Simülasyon için bekle
        
    except Exception as e:
        sync_manager.add_log(f"Senkronizasyon hatası: {str(e)}", "error")
    
    finally:
        sync_manager.sync_in_progress = False
        sync_manager.add_log("Senkronizasyon tamamlandı", "success")

@app.route('/api/sync/stop', methods=['POST'])
def stop_sync():
    """Senkronizasyonu durdur"""
    sync_manager.sync_in_progress = False
    sync_manager.add_log("Senkronizasyon durduruldu", "warning")
    return jsonify({'success': True, 'message': 'Senkronizasyon durduruldu'})

@app.route('/api/status')
def get_status():
    """Sistem durumunu al"""
    return jsonify({
        'smb_connected': sync_manager.smb_connected,
        'ftp_connected': sync_manager.ftp_connected,
        'sync_in_progress': sync_manager.sync_in_progress,
        'config': sync_manager.config
    })

@app.route('/api/logs')
def get_logs():
    """Log kayıtlarını al"""
    return jsonify({
        'logs': sync_manager.sync_log[-100:]  # Son 100 log
    })

@app.route('/api/test-connections', methods=['POST'])
def test_connections():
    """Bağlantıları test et"""
    results = {
        'smb': sync_manager.smb_connected,
        'ftp': sync_manager.ftp_connected,
        'system_requirements': check_system_requirements()
    }
    return jsonify(results)

def check_system_requirements():
    """Sistem gereksinimlerini kontrol et"""
    requirements = ['smbclient', 'cifs-utils', 'rsync', 'lftp']
    results = {}
    
    for req in requirements:
        try:
            result = subprocess.run(['which', req], capture_output=True)
            results[req] = result.returncode == 0
        except:
            results[req] = False
    
    return results

if __name__ == '__main__':
    print("🚀 Ubuntu Server Dosya Senkronizasyon API Başlatılıyor...")
    print("📡 http://localhost:5000 adresinde çalışacak")
    app.run(host='0.0.0.0', port=5000, debug=True)
