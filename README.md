# Docker Squid Proxy Environment with Webmin & PAC

## 1. 概要

アプリ動作検証用の **Squid Proxy 環境** を Docker で手軽に構築するためのプロジェクトです。
GUI 管理ツール（Webmin）と、PAC ファイル配布サーバー（Nginx）を同梱しており、以下の検証が可能です。

- **プロキシ経由での通信検証**: アプリが正しくプロキシを経由するか、特定の通信がブロックされるか。
- **通信ログの可視化**: どのドメインにアクセスしているかをリアルタイムで確認。
- **PAC / WPAD の検証**: 自動構成スクリプト (`proxy.pac`) を用いた振り分け動作の確認。
- **帯域制限のシミュレーション**: 低速回線時のアプリ挙動の確認。

## 2. 構成

| コンテナ名     | イメージベース | 役割                                                            | ポート                      |
| :------------- | :------------- | :-------------------------------------------------------------- | :-------------------------- |
| **squid-main** | Ubuntu 24.04   | **Squid Proxy**: プロキシ本体<br>**Webmin**: GUI 管理・ログ閲覧 | 3128 (Proxy)<br>10000 (GUI) |
| **pac-server** | Nginx (Alpine) | **Web Server**: `proxy.pac` ファイルの配布                      | 80                          |

## 3. ディレクトリ構成

配布時は以下の構成でファイルを配置してください。

```text
.
├── Dockerfile          # Squid + Webmin 環境構築定義
├── docker-compose.yml  # サービス起動定義
├── entrypoint.sh       # 起動・設定スクリプト
├── webmin.deb          # Webminインストールパッケージ (※要手動配置)
└── html/
    └── proxy.pac       # プロキシ自動構成スクリプト
```

## 4. 導入手順

### 事前準備

1.  **Webmin パッケージのダウンロード**
    - Ubuntu 24.04 対応のため、Sourceforge 等から `.deb` ファイルをダウンロードし、`webmin.deb` にリネームしてプロジェクトルートに配置してください。
    - 推奨ファイル: `newkey-webmin_2.610_all.deb` (バージョンは適宜最新へ)
    - [Sourceforge ダウンロードリンク](http://prdownloads.sourceforge.net/webadmin/webmin_current_all.deb)

### 起動

ターミナル（PowerShell / Git Bash 等）で以下のコマンドを実行します。

```bash
# ビルドと起動
docker compose up -d --build

# 状態確認（Statusが Up になっていること）
docker compose ps
```

## 5. 使い方

### A. プロキシサーバーへの接続

- **プロキシサーバー**: `localhost`
- **ポート**: `3128`
- **Web 管理画面 (Webmin)**: [http://localhost:10000](http://localhost:10000)
  - **User**: `root`
  - **Pass**: `docker-compose.yml` 内の `ROOT_PASSWORD` (デフォルト: `password`)

### B. ログの確認 (リアルタイム)

通信ログをリアルタイムで確認するには、以下のコマンドを使用します。

```bash
# 全ログを表示
docker compose logs -f

# 特定の文字列（例: CONNECT）で絞り込む場合 (Git Bash推奨)
docker compose logs -f | grep --line-buffered "CONNECT"
```

### C. PAC ファイルの利用 (自動構成)

1.  Windows の「ネットワークとインターネット」設定 > 「プロキシ」を開く。
2.  **「セットアップ スクリプトを使う」** をオンにする。
3.  **「スクリプトのアドレス」** に `http://localhost/proxy.pac` を入力して保存。
4.  ブラウザでアクセスし、PAC ファイルの記述通りにプロキシが利用されるか確認する。
    - PAC ファイルの編集は `html/proxy.pac` を直接編集（即反映されます）。

## 6. Webmin での設定例

### 特定ドメインのブロック

1.  Webmin 左メニュー: **Servers** > **Squid Proxy Server**
2.  **Access Control Lists** > **Create new ACL**
    - Type: `Web Server Hostname`
    - Name: `blocked_sites`
    - Domains: `.yahoo.co.jp` 等
3.  **Proxy Restrictions** > **Add proxy restriction**
    - Action: `Deny`
    - Match ACLs: `blocked_sites` を選択
4.  一覧の上位にルールを移動し、**Apply Changes** をクリック。

### 帯域制限 (Delay Pools)

**Edit Config Files** から `squid.conf` に以下を追記して適用します。

```squid
# 全体で約 50KB/s に制限する設定例
delay_pools 1
delay_class 1 1
delay_access 1 allow all
delay_parameters 1 51200/51200
```

## 7. 注意事項・トラブルシューティング

- **VPN 環境での利用**:
  - VPN 接続中はコンテナのビルド（外部へのダウンロード）が失敗することがあります。ビルド時は一時的に VPN を切断してください。
  - VPN クライアントによっては `localhost` への通信を遮断する場合があります。
- **PowerShell での検証**:
  - `curl` コマンドはエイリアスにより動作しないため、`curl.exe` と入力してください。
  - `curl` コマンドは PAC 設定を読み込みません（PAC 検証はブラウザで行ってください）。
- **セキュリティ**:
  - 本環境は検証用として `http_access allow all`（全許可）および SSL 無効化を行っています。**インターネットに公開されているサーバーには絶対にデプロイしないでください。**

---

### 付録: 最終版ファイル構成

もしファイル作成が必要な場合は、以下を使用してください。

<details>
<summary><b>Dockerfile (クリックして展開)</b></summary>

```dockerfile
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# 1. ツールインストール
RUN apt-get update && apt-get install -y \
    squid wget gnupg unzip openssl systemd python3 \
    perl libnet-ssleay-perl libauthen-pam-perl libio-pty-perl libpam-runtime shared-mime-info \
    net-tools iproute2 dnsutils iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# 2. Webminインストール (手動配置ファイル利用・ロック回避版)
COPY webmin.deb /tmp/webmin.deb
RUN dpkg -i /tmp/webmin.deb || true && \
    apt-get update && \
    apt-get -f install -y && \
    rm /tmp/webmin.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 3. 設定
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
EXPOSE 3128 10000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
```

</details>

<details>
<summary><b>entrypoint.sh (クリックして展開)</b></summary>

```bash
#!/bin/bash
set -e

# Webminパスワード
WEBMIN_PASS=${ROOT_PASSWORD:-password}
echo "root:$WEBMIN_PASS" | chpasswd

# Webmin設定 (SSL無効化・アクセス許可)
if [ -f "/etc/webmin/miniserv.conf" ]; then
    sed -i 's/ssl=1/ssl=0/g' /etc/webmin/miniserv.conf
    sed -i 's/allow=127.0.0.1/allow=0.0.0.0/g' /etc/webmin/miniserv.conf 2>/dev/null || true
fi
/etc/init.d/webmin start || echo "Webmin start failed, but continuing..."

# Squid設定
SQUID_CONF="/etc/squid/squid.conf"
CACHE_DIR="/var/spool/squid"
LOG_DIR="/var/log/squid"

if ! grep -q "http_access allow all" "$SQUID_CONF"; then
    sed -i 's/http_access deny all/http_access allow all/g' "$SQUID_CONF"
fi

# 権限修正
mkdir -p "$LOG_DIR" "$CACHE_DIR" /run/squid
chown -R proxy:proxy "$LOG_DIR" "$CACHE_DIR" /run/squid
chmod 755 "$LOG_DIR" "$CACHE_DIR"
touch "$LOG_DIR/access.log" "$LOG_DIR/cache.log"
chown proxy:proxy "$LOG_DIR/access.log" "$LOG_DIR/cache.log"

# キャッシュ初期化
if [ ! -d "$CACHE_DIR/00" ]; then
    su -s /bin/sh -c "squid -z" proxy
    sleep 3
fi

echo "Ready: Squid(3128), Webmin(10000)"
tail -F "$LOG_DIR/access.log" "$LOG_DIR/cache.log" &
exec squid -N -Y
```

</details>

<details>
<summary><b>docker-compose.yml (クリックして展開)</b></summary>

```yaml
services:
  squid-webmin:
    build: .
    container_name: squid-main
    ports:
      - "3128:3128"
      - "10000:10000"
    environment:
      - ROOT_PASSWORD=password
    restart: always

  pac-server:
    image: nginx:alpine
    container_name: pac-server
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html
    restart: always
```

</details>
