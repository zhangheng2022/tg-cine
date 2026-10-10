import assert from "node:assert/strict";
import test from "node:test";
import { relayEndpoint, createRelayTransport, fallbackConnector } from "../scripts/relay-transport.mjs";
import { DC_HOSTS } from "../worker.mjs";

test("SDK DC and media aliases map to fixed relay routes; unknown targets are rejected", () => {
  for (const [dc, hostname] of Object.entries(DC_HOSTS)) {
    assert.equal(relayEndpoint(`wss://${hostname}/apiws`, "wss://relay.example"), `wss://relay.example/dc/${dc}`);
    assert.equal(relayEndpoint(`wss://${hostname.replace('.web.', '-1.web.')}/apiws`, "wss://relay.example"), `wss://relay.example/dc/${dc}`);
  }
  assert.equal(relayEndpoint("wss://relay.example/dc/2", "wss://relay.example"), "wss://relay.example/dc/2");
  for (const source of ["wss://attacker.example/apiws", "ws://venus.web.telegram.org/apiws", "wss://venus.web.telegram.org/apiws_test", "wss://relay.example/dc/9"]) {
    assert.throws(() => relayEndpoint(source, "wss://relay.example"), /Unsupported/);
  }
});

test("failed connections fall back once; successful connections and final errors propagate", async () => {
  const attempts = [];
  const socket = {};
  const connector = fallbackConnector([
    (_, callback) => callback(new Error("TLS reset")),
    (_, callback) => callback(null, socket),
    () => assert.fail("third address must not be dialled"),
  ], attempts);
  const result = await new Promise((resolve, reject) => connector({}, (error, result) => error ? reject(error) : resolve(result)));
  assert.equal(result, socket);
  assert.deepEqual(attempts.map(({ index, ok }) => ({ index, ok })), [{ index: 0, ok: false }, { index: 1, ok: true }]);
  const failed = fallbackConnector([(_, cb) => cb(new Error("first")), (_, cb) => cb(new Error("last"))]);
  await assert.rejects(new Promise((resolve, reject) => failed({}, error => error ? reject(error) : resolve())), /last/);
});

test("direct relay transport fails closed for invalid configuration", async () => {
  const token = "a".repeat(43);
  assert.throws(() => createRelayTransport("ws://relay.example", "172.67.149.41", token), /RELAY_URL/);
  assert.throws(() => createRelayTransport("wss://relay.example", "198.18.0.1", token), /RELAY_IP/);
  assert.throws(() => createRelayTransport("wss://relay.example", "172.67.149.41,127.0.0.1", token), /RELAY_IP/);
  assert.throws(() => createRelayTransport("wss://relay.example", "10.0.0.1", token), /RELAY_IP/);
  assert.throws(() => createRelayTransport("wss://relay.example", "172.67.149.41", "short"), /secret/);
  const transport = createRelayTransport("wss://relay.example", "172.67.149.41", token);
  assert.throws(() => new transport.RelayWebSocket("wss://attacker.example/apiws"), /Unsupported/);
  await transport.agent.destroy();
});
