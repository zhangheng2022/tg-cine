import assert from "node:assert/strict";
import { createServer } from "node:http";
import { once } from "node:events";
import test from "node:test";
import { probe } from "../scripts/probe.mjs";

test("network probe reports rejected upgrades and cancels a hanging handshake", async () => {
  const server = createServer();
  const sockets = new Set();
  let reject = true;
  server.on("connection", socket => {
    sockets.add(socket);
    socket.on("close", () => sockets.delete(socket));
  });
  server.on("upgrade", (request, socket) => {
    if (reject) socket.end("HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\n\r\n");
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  try {
    const endpoint = `ws://127.0.0.1:${server.address().port}/dc/2`;
    const denied = await probe(endpoint, undefined, 1000);
    assert.equal(denied.ok, false);
    assert.equal(denied.stage, "websocket");
    assert.equal(denied.error, "WebSocket connection failed");
    reject = false;
    const hanging = await probe(endpoint, undefined, 100);
    assert.equal(hanging.ok, false);
    assert.equal(hanging.error, "Timeout");
    assert.ok(hanging.elapsedMs >= 90 && hanging.elapsedMs < 1000);
  } finally {
    for (const socket of sockets) socket.destroy();
    await new Promise(resolve => server.close(resolve));
  }
});
