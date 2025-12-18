function FindProxyForURL(url, host) {
  // ローカルアドレスはプロキシを通さない
  if (
    isPlainHostName(host) ||
    shExpMatch(host, "*.local") ||
    isInNet(dnsResolve(host), "10.0.0.0", "255.0.0.0") ||
    isInNet(dnsResolve(host), "192.168.0.0", "255.255.0.0") ||
    isInNet(dnsResolve(host), "127.0.0.0", "255.0.0.0")
  ) {
    return "DIRECT";
  }

  // Googleへのアクセスのみプロキシ(Squid)を通す例
  if (shExpMatch(host, "*.google.com")) {
    // DockerホストのIPを指定 (localhostだとブラウザ側で自分自身を指してしまうため注意)
    // 誰かに配る場合は、ここのIPを書き換えてもらうか、PCのホスト名を指定します
    return "PROXY localhost:3128";
  }

  // それ以外はSquidを通す
  return "PROXY localhost:3128";
}
