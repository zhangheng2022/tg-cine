import { mkdir, writeFile } from "node:fs/promises";
import { lookup } from "node:dns/promises";
import { pathToFileURL } from "node:url";
import { DC_HOSTS } from "../worker.mjs";
import { createProbe } from "./protocol.mjs";

export async function probe(endpoint, token, timeoutMs = 12000, WebSocketCtor = globalThis.WebSocket) {
  const started = performance.now();
  let stage = "websocket";
  return new Promise(resolve => {
    let socket;
    let finished = false;
    const timer = setTimeout(() => finish({ ok: false, error: "Timeout" }), timeoutMs);
    function finish(result) {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      if (socket && socket.readyState < WebSocketCtor.CLOSING) socket.close();
      const url = new URL(endpoint);
      resolve({ endpoint: `${url.origin}${url.pathname}`, stage,
        elapsedMs: Math.round(performance.now() - started), ...result });
    }
    try {
      const handshake = createProbe();
      socket = new WebSocketCtor(endpoint, token ? ["binary", `tg-auth.${token}`] : ["binary"]);
      socket.binaryType = "arraybuffer";
      socket.addEventListener("open", () => {
        if (finished) { socket.close(); return; }
        if (socket.protocol !== "binary") return finish({ ok: false, error: "Binary protocol not negotiated" });
        stage = "mtproto";
        socket.send(handshake.header);
        socket.send(handshake.packet);
      });
      socket.addEventListener("message", event => {
        if (finished) return;
        try {
          if (!(event.data instanceof ArrayBuffer)) throw new Error("Expected binary reply");
          const result = handshake.receive(Buffer.from(event.data));
          if (result) finish({ ok: true, ...result });
        } catch (error) { finish({ ok: false, error: error.message }); }
      });
      socket.addEventListener("error", () => finish({ ok: false, error: "WebSocket connection failed" }));
      socket.addEventListener("close", event => finish({ ok: false, error: `Closed before resPQ (${event.code})` }));
    } catch (error) {
      finish({ ok: false, error: error instanceof TypeError ? "Invalid WebSocket configuration" : error.message });
    }
  });
}

async function main() {
  const relay = process.env.RELAY_URL;
  const token = process.env.RELAY_TOKEN;
  if (relay) {
    const url = new URL(relay);
    if (url.username || url.password || url.search || url.hash ||
        !(url.protocol === "wss:" || (url.protocol === "ws:" && url.hostname === "127.0.0.1"))) {
      throw new Error("RELAY_URL must be wss://host or local ws://127.0.0.1:port, without credentials/query");
    }
    if (!/^[A-Za-z0-9_-]{32,128}$/.test(token ?? "")) throw new Error("Configure RELAY_TOKEN first");
  }
  const results = await Promise.all(Object.entries(DC_HOSTS).map(async ([dc, host]) => {
    const dns = await lookup(host, { all: true }).catch(() => []);
    const endpoint = relay ? `${relay.replace(/\/$/, "")}/dc/${dc}` : `wss://${host}/apiws`;
    return { dc: Number(dc), dns, ...await probe(endpoint, relay ? token : undefined) };
  }));
  const report = {
    checkedAt: new Date().toISOString(), node: process.version,
    mode: relay ? "relay" : "direct", explicitProxyConfigured: false,
    scope: "WSS + obfuscated abridged transport + req_pq_multi/resPQ only; not DH authentication, account login or video playback",
    results,
  };
  await mkdir("results", { recursive: true });
  await writeFile(`results/${report.mode}.json`, JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify(report, null, 2));
  if (results.some(result => !result.ok)) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
