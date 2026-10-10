import assert from "node:assert/strict";
import test from "node:test";
import worker, { DC_HOSTS } from "../worker.mjs";

const token = "a".repeat(43);
const env = { RELAY_TOKEN: token };
function request(path = "/dc/2", headers = {}, method = "GET") {
  return new Request(`https://relay.example${path}`, {
    method, headers: { Upgrade: "websocket", "Sec-WebSocket-Protocol": `binary, tg-auth.${token}`, ...headers },
  });
}

test("relay fails closed for missing secrets, credentials, non-WS, invalid DCs and target injection", async () => {
  const cases = [
    [request(), {}, 503],
    [request("/dc/2", {}, "POST"), env, 405],
    [request("/dc/2", { Upgrade: "http" }), env, 426],
    [request("/dc/2", { "Sec-WebSocket-Protocol": "binary" }), env, 401],
    [request("/dc/2", { "Sec-WebSocket-Protocol": `tg-auth.${token}` }), env, 401],
    [request("/dc/0"), env, 404],
    [request("/dc/2?url=https://attacker.example"), env, 404],
    [request("/https://attacker.example"), env, 404],
  ];
  for (const [req, bindings, expected] of cases) assert.equal((await worker.fetch(req, bindings)).status, expected);
});

test("relay pins all five upstreams, strips secrets/cookies, preserves upgrade; errors stay isolated", async () => {
  const original = globalThis.fetch;
  try {
    for (const [dc, host] of Object.entries(DC_HOSTS)) {
      const upstream = { status: 101, webSocket: {} };
      globalThis.fetch = async (url, options) => {
        assert.equal(url, `https://${host}/apiws`);
        assert.deepEqual(options.headers, { Upgrade: "websocket", "Sec-WebSocket-Protocol": "binary" });
        assert.equal(options.redirect, "manual");
        return upstream;
      };
      assert.equal(await worker.fetch(request(`/dc/${dc}`, { Cookie: "private", Authorization: "private" }), env), upstream);
    }
    globalThis.fetch = async () => new Response("redirect", { status: 302 });
    assert.equal((await worker.fetch(request(), env)).status, 502);
    globalThis.fetch = async () => { throw new Error("network detail/secret"); };
    const response = await worker.fetch(request(), env);
    assert.equal(response.status, 502);
    assert.equal(await response.text(), "Telegram connection failed");
  } finally { globalThis.fetch = original; }
});
