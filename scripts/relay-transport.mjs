import { isIP } from "node:net";
import { Agent, WebSocket, buildConnector } from "undici";
import { DC_HOSTS } from "../worker.mjs";

export function relayEndpoint(source, relayUrl) {
  const url = new URL(source);
  const relay = new URL(relayUrl);
  if (url.origin === relay.origin && /^\/dc\/[1-5]$/.test(url.pathname) && !url.search) return url.href;
  const dc = Object.entries(DC_HOSTS).find(([, host]) => host === url.hostname.replace("-1.web.", ".web."))?.[0];
  if (!dc || url.protocol !== "wss:" || url.pathname !== "/apiws" || url.search) {
    throw new Error("Unsupported Telegram WebSocket target");
  }
  return `${relay.origin}/dc/${dc}`;
}

export function fallbackConnector(connectors, attempts = []) {
  return (options, callback) => {
    let index = 0;
    function next() {
      const current = index++;
      const started = performance.now();
      connectors[current](options, (error, socket) => {
        attempts.push({ index: current, ok: !error, elapsedMs: Math.round(performance.now() - started) });
        if (error && index < connectors.length) next();
        else callback(error, socket);
      });
    }
    next();
  };
}

export function createRelayTransport(relayUrl, relayIp, token) {
  const relay = new URL(relayUrl);
  if (relay.protocol !== "wss:" || relay.pathname !== "/" || relay.search || relay.hash || relay.username || relay.password) {
    throw new Error("RELAY_URL must be a wss:// hostname without path, query or credentials");
  }
  const ips = [...new Set(String(relayIp ?? "").split(",").map(value => value.trim()))];
  if (!ips.length || ips.length > 4 || ips.some(ip => isIP(ip) !== 4 ||
      /^(0\.|10\.|127\.|169\.254\.|192\.168\.|198\.(18|19)\.)/.test(ip) ||
      /^172\.(1[6-9]|2\d|3[01])\./.test(ip) || Number(ip.split(".")[0]) >= 224)) {
    throw new Error("RELAY_IP must contain 1–4 verified public IPv4 addresses, not private, fake-IP or loopback addresses");
  }
  if (!/^[A-Za-z0-9_-]{32,128}$/.test(token ?? "")) throw new Error("Invalid relay secret");
  const attempts = [];
  // shortcut: verified addresses avoid intercepted DNS; refresh them when Cloudflare DNS changes.
  const connectors = ips.map(ip => buildConnector({ autoSelectFamily: false, timeout: Math.min(4000, Math.floor(8000 / ips.length)),
    lookup(hostname, options, callback) {
      if (hostname !== relay.hostname) return callback(new Error("Unexpected upstream hostname"));
      callback(null, ...(options.all ? [[{ address: ip, family: 4 }]] : [ip, 4]));
    },
  }));
  const connect = fallbackConnector(connectors, attempts);
  const agent = new Agent({ connect(options, callback) {
    if (options.hostname !== relay.hostname) return callback(new Error("Unexpected upstream hostname"));
    connect(options, callback);
  } });
  class RelayWebSocket extends WebSocket {
    constructor(url) {
      super(relayEndpoint(url, relayUrl), {
        protocols: ["binary", `tg-auth.${token}`], dispatcher: agent,
      });
    }
  }
  return { agent, RelayWebSocket, ips, attempts };
}
