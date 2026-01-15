#!/bin/bash
set -e

# Webmin用のrootパスワード設定
WEBMIN_PASS=${ROOT_PASSWORD:-password}
echo "root:$WEBMIN_PASS" | chpasswd

# --- Webmin設定 ---
if [ -f "/etc/webmin/miniserv.conf" ]; then
    sed -i 's/ssl=1/ssl=0/g' /etc/webmin/miniserv.conf
    sed -i 's/allow=127.0.0.1/allow=0.0.0.0/g' /etc/webmin/miniserv.conf 2>/dev/null || true
fi

echo "Starting Webmin..."
/etc/init.d/webmin start || echo "Webmin start failed, but continuing..."

# Webminの起動完了を待機（ポート10000がリッスン状態になるまで）
echo "Waiting for Webmin to be ready..."
for i in $(seq 1 30); do
    if ss -tlnp 2>/dev/null | grep -q ':10000'; then
        echo "Webmin is ready!"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "Warning: Webmin may not have started properly (timeout after 30s)"
    fi
    sleep 1
done

# --- Squid設定 ---
SQUID_CONF="/etc/squid/squid.conf"
CACHE_DIR="/var/spool/squid"
LOG_DIR="/var/log/squid"

# 1. コンテナ外部からのアクセス許可
if ! grep -q "http_access allow all" "$SQUID_CONF"; then
    echo "Configuring Squid to allow all access..."
    sed -i 's/http_access deny all/http_access allow all/g' "$SQUID_CONF"
fi

# 2. 権限とログファイルの事前準備 (Permission Denied対策)
echo "Fixing permissions..."

# ディレクトリ自体の所有権変更
mkdir -p "$LOG_DIR" "$CACHE_DIR"
chown -R proxy:proxy "$LOG_DIR" "$CACHE_DIR"
chmod 755 "$LOG_DIR" "$CACHE_DIR"

# ログファイルを空作成して権限付与
touch "$LOG_DIR/access.log" "$LOG_DIR/cache.log"
chown proxy:proxy "$LOG_DIR/access.log" "$LOG_DIR/cache.log"

# PIDファイル用のディレクトリ権限修正 (Squidはここに書き込もうとする)
mkdir -p /run/squid
chown -R proxy:proxy /run/squid

# 3. キャッシュディレクトリの初期化
if [ ! -d "$CACHE_DIR/00" ]; then
    echo "Initializing Squid cache..."
    # proxyユーザーとして初期化コマンドを実行
    su -s /bin/sh -c "squid -z" proxy
    sleep 3
fi

echo "=================================================="
echo " Proxy Setup Complete"
echo " Squid Proxy : Port 3128"
echo " Webmin GUI  : http://localhost:10000"
echo "=================================================="

# ログをバックグラウンドで表示 (access.log と cache.log 両方を見る)
tail -F "$LOG_DIR/access.log" "$LOG_DIR/cache.log" &

# Squidを起動
# -N: デーモン化しない
# -Y: DNSテストを省略して高速起動 (VPN環境対策)
echo "Starting Squid process..."
exec squid -N -Y