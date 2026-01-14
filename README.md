# Docker Squid Proxy Environment with Webmin & PAC

## 1. 概要

アプリ動作検証用の **Squid Proxy 環境** を Docker で手軽に構築するためのプロジェクトです。
GUI 管理ツール（Webmin）と、PAC ファイル配布サーバー（Nginx）を同梱しており、以下の検証が可能です。

- **プロキシ経由での通信検証**: アプリが正しくプロキシを経由するか、特定の通信がブロックされるか
- **通信ログの可視化**: どのドメインにアクセスしているかをリアルタイムで確認
- **PAC / WPAD の検証**: 自動構成スクリプト (`proxy.pac`) を用いた振り分け動作の確認
- **帯域制限のシミュレーション**: 低速回線時のアプリ挙動の確認

## 2. 構成

| コンテナ名     | イメージベース | 役割                                                            | ポート                      |
| :------------- | :------------- | :-------------------------------------------------------------- | :-------------------------- |
| **squid-main** | Ubuntu 24.04   | **Squid Proxy**: プロキシ本体<br>**Webmin**: GUI 管理・ログ閲覧 | 3128 (Proxy)<br>10000 (GUI) |
| **pac-server** | Nginx (Alpine) | **Web Server**: `proxy.pac` ファイルの配布                      | 80                          |

## 3. Windows ユーザー向けセットアップ

Docker がインストールされていない Windows 環境では、**Rancher Desktop**（無料）を使用してください。

> [!NOTE]
> Docker Desktop は大企業向けに有償化されています（従業員250人以上または年間売上$10M以上）。  
> Rancher Desktop は完全無料（Apache 2.0 ライセンス）で、同等の機能を提供します。

### インストール手順

1. **Rancher Desktop をダウンロード**  
   https://rancherdesktop.io/ から Windows 版をダウンロード

2. **インストーラーを実行**（管理者権限が必要）

3. **初回起動時の設定**  
   - **Container Engine**: `dockerd (moby)` を選択  
     ※ これにより `docker` コマンドがそのまま使用可能になります
   - **Kubernetes**: 不要な場合は無効化して軽量化できます

4. **ターミナル（PowerShell / Git Bash 等）を開いて動作確認**
   ```powershell
   docker --version
   ```

インストール完了後、以下のクイックスタートに進んでください。

### Mac ユーザー向けセットアップ

Mac 環境でも **Rancher Desktop**（無料）を使用できます。

#### Homebrew でインストール（推奨）

```bash
brew install --cask rancher

# インストール後、アプリケーションから Rancher Desktop を起動
```

#### 手動インストール

1. https://rancherdesktop.io/ から macOS 版（Intel / Apple Silicon）をダウンロード
2. `.dmg` を開き、アプリケーションフォルダにドラッグ
3. 初回起動時に **Container Engine** で `dockerd (moby)` を選択
4. ターミナルで `docker --version` を実行して動作確認

## 4. クイックスタート（推奨）

ビルド済みイメージを使用するため、**ビルド不要**で即起動できます。

```bash
# 1. リポジトリをクローン
git clone https://github.com/yosmoris/squid-webmin-docker.git
cd squid-webmin-docker

# 2. 起動（イメージは自動でダウンロードされます）
docker compose up -d

# 3. 状態確認（Status が running になっていること）
docker compose ps
```

### 最小構成で起動（クローン不要）

```bash
mkdir squid-proxy && cd squid-proxy
curl -sLO https://raw.githubusercontent.com/yosmoris/squid-webmin-docker/main/docker-compose.yml
mkdir -p html
curl -sL https://raw.githubusercontent.com/yosmoris/squid-webmin-docker/main/html/proxy.pac -o html/proxy.pac
docker compose up -d
```

## 5. アクセス情報

| サービス     | URL / 設定                                               |
| :----------- | :------------------------------------------------------- |
| Proxy Server | `localhost:3128`                                         |
| Webmin GUI   | [http://localhost:10000](http://localhost:10000)         |
| Webmin 認証  | ユーザー: `root` / パスワード: `password`                |
| PAC URL      | [http://localhost/proxy.pac](http://localhost/proxy.pac) |

## 6. 使い方

### A. プロキシサーバーへの接続

ブラウザやアプリのプロキシ設定で以下を指定してください。

- **プロキシサーバー**: `localhost`
- **ポート**: `3128`

### B. ログの確認（リアルタイム）

```bash
# 全ログを表示
docker compose logs -f

# 特定の文字列（例: CONNECT）で絞り込む場合
docker compose logs -f | grep --line-buffered "CONNECT"
```

### C. PAC ファイルの利用（自動構成）

1. Windows の「設定」→「ネットワークとインターネット」→「プロキシ」を開く
2. **「セットアップ スクリプトを使う」** をオンにする
3. **「スクリプトのアドレス」** に `http://localhost/proxy.pac` を入力して保存
4. PAC ファイルの編集は `html/proxy.pac` を直接編集（即反映されます）

### D. 停止・削除

```bash
# 停止
docker compose down

# 停止 + ボリューム削除
docker compose down -v
```

## 7. Webmin での設定例

### 特定ドメインのブロック

1. Webmin 左メニュー: **Servers** > **Squid Proxy Server**
2. **Access Control Lists** > **Create new ACL**
   - Type: `Web Server Hostname`
   - Name: `blocked_sites`
   - Domains: `.yahoo.co.jp` 等
3. **Proxy Restrictions** > **Add proxy restriction**
   - Action: `Deny`
   - Match ACLs: `blocked_sites` を選択
4. 一覧の上位にルールを移動し、**Apply Changes** をクリック

### 帯域制限 (Delay Pools)

**Edit Config Files** から `squid.conf` に以下を追記して適用します。

```squid
# 全体で約 50KB/s に制限する設定例
delay_pools 1
delay_class 1 1
delay_access 1 allow all
delay_parameters 1 51200/51200
```

## 8. 開発者向け（ローカルビルド）

Dockerfile を修正してテストする場合は、開発者用の compose ファイルを使用してください。

```bash
# 1. Webmin パッケージをダウンロード
wget http://prdownloads.sourceforge.net/webadmin/webmin_2.111_all.deb -O webmin.deb

# 2. ビルド＆起動
docker compose -f docker-compose.dev.yml up -d --build
```

## 9. ディレクトリ構成

```text
.
├── docker-compose.yml       # 利用者向け（ghcr.io からイメージを Pull）
├── docker-compose.dev.yml   # 開発者向け（ローカルビルド用）
├── Dockerfile               # イメージ構築定義（GitHub Actions で使用）
├── entrypoint.sh            # コンテナ起動スクリプト
├── html/
│   └── proxy.pac            # プロキシ自動構成スクリプト
└── .github/
    └── workflows/
        └── docker-publish.yml  # 自動ビルド・公開ワークフロー
```

## 10. 注意事項・トラブルシューティング

### VPN 環境での利用

- VPN クライアントによっては `localhost` への通信を遮断する場合があります
- 開発者向けのローカルビルド時、VPN 接続中は外部へのダウンロードが失敗することがあります

### PowerShell での検証

- `curl` コマンドはエイリアスにより動作しないため、`curl.exe` と入力してください
- `curl` コマンドは PAC 設定を読み込みません（PAC 検証はブラウザで行ってください）

### セキュリティ

> ⚠️ **警告**: 本環境は検証用として `http_access allow all`（全許可）および SSL 無効化を行っています。**インターネットに公開されているサーバーには絶対にデプロイしないでください。**

## 11. ライセンス

MIT License
