#!/usr/bin/env node
// コンテナ内 127.0.0.1:<port> へのTCP接続をホスト側Chromeの
// リモートデバッグポート(CDP)へ中継する。
//
// Chrome DevTools ProtocolはHTTPリクエストのHostヘッダーが
// "localhost" または IPアドレス以外だと拒否するため、
// host.docker.internal へ直接アクセスすることができない。
// このプロキシを経由して 127.0.0.1 宛にアクセスさせることで
// Hostヘッダーを127.0.0.1に保ったままホスト側Chromeへ届ける。
"use strict";

const net = require("net");

const targetHost = process.env.NLM_CDP_TARGET_HOST || "host.docker.internal";
const targetPort = Number(process.env.NLM_CDP_TARGET_PORT || 9222);
const listenPort = Number(process.env.NLM_CDP_LISTEN_PORT || 9222);

const server = net.createServer((client) => {
  const upstream = net.connect({ host: targetHost, port: targetPort }, () => {
    client.pipe(upstream).pipe(client);
  });
  upstream.on("error", () => client.destroy());
  client.on("error", () => upstream.destroy());
});

server.on("error", (err) => {
  console.error(`[cdp-proxy] listen error: ${err.message}`);
  process.exit(1);
});

server.listen(listenPort, "127.0.0.1", () => {
  console.log(
    `[cdp-proxy] 127.0.0.1:${listenPort} -> ${targetHost}:${targetPort}`
  );
});

for (const sig of ["SIGINT", "SIGTERM"]) {
  process.on(sig, () => {
    server.close(() => process.exit(0));
  });
}
