FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. 必要なツールのインストール
# Webminがシステム情報を取得するために必要なネットワークツールを追加しました
# (net-tools, iproute2, dnsutils, iputils-ping)
RUN apt-get update && apt-get install -y \
    squid \
    wget \
    gnupg \
    unzip \
    openssl \
    systemd \
    perl \
    libnet-ssleay-perl \
    libauthen-pam-perl \
    libio-pty-perl \
    libpam-runtime \
    shared-mime-info \
    python3 \
    net-tools \
    iproute2 \
    dnsutils \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# 2. Webminのインストール (手動配置ファイルを使用)
# ロックエラー回避のため、dpkg -i でインストールし、依存関係エラーを apt-get -f install で解決
COPY webmin.deb /tmp/webmin.deb

RUN dpkg -i /tmp/webmin.deb || true && \
    apt-get update && \
    apt-get -f install -y && \
    rm /tmp/webmin.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 3. 起動スクリプトの配置
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ポート公開
EXPOSE 3128 10000

# 起動
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]