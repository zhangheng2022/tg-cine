export const DC_HOSTS = Object.freeze({
  1: "pluto.web.telegram.org",
  2: "venus.web.telegram.org",
  3: "aurora.web.telegram.org",
  4: "vesta.web.telegram.org",
  5: "flora.web.telegram.org",
});

export default {
  async fetch(request, env) {
    if (!/^[A-Za-z0-9_-]{32,128}$/.test(env.RELAY_TOKEN ?? "")) {
      return new Response("Relay secret is not configured", { status: 503 });
    }
    if (request.method !== "GET") return new Response("GET only", { status: 405 });
    const url = new URL(request.url);
    const match = /^\/dc\/([1-5])$/.exec(url.pathname);
    if (!match || url.search) return new Response("Unknown DC route", { status: 404 });
    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("WebSocket required", { status: 426 });
    }
    const protocols = (request.headers.get("Sec-WebSocket-Protocol") ?? "")
      .split(",").map(value => value.trim());
    if (!protocols.includes("binary") || !protocols.includes(`tg-auth.${env.RELAY_TOKEN}`)) {
      return new Response("Unauthorized", { status: 401 });
    }
    const abort = new AbortController();
    const timeout = setTimeout(() => abort.abort(), 10000);
    try {
      // Only the binary protocol goes upstream; no caller URL, cookie or relay secret is forwarded.
      const upstream = await fetch(`https://${DC_HOSTS[match[1]]}/apiws`, {
        method: "GET",
        headers: { Upgrade: "websocket", "Sec-WebSocket-Protocol": "binary" },
        redirect: "manual",
        signal: abort.signal,
      });
      if (upstream.status !== 101 || !upstream.webSocket) {
        return new Response("Telegram upgrade failed", { status: 502 });
      }
      return upstream;
    } catch {
      return new Response("Telegram connection failed", { status: 502 });
    } finally {
      clearTimeout(timeout);
    }
  },
};
