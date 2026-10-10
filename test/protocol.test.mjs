import assert from "node:assert/strict";
import { createCipheriv, createDecipheriv } from "node:crypto";
import test from "node:test";
import { createProbe, parseResPQ } from "../scripts/protocol.mjs";

function reply(nonce) {
  const message = Buffer.alloc(84);
  message.writeBigUInt64LE((BigInt(Math.floor(Date.now() / 1000)) << 32n) | 1n, 8);
  message.writeUInt32LE(64, 16);
  message.writeUInt32LE(0x05162463, 20);
  nonce.copy(message, 24);
  message.fill(0x31, 40, 56);
  message[56] = 8;
  message.fill(0x23, 57, 65);
  message.writeUInt32LE(0x1cb5c415, 68);
  message.writeUInt32LE(1, 72);
  message.writeBigUInt64LE(0xc3b42b026ce86b21n, 76);
  return message;
}

test("obfuscated request decrypts correctly; fragmented encrypted resPQ validates", () => {
  const check = createProbe();
  const serverRead = createDecipheriv("aes-256-ctr", check.header.subarray(8, 40), check.header.subarray(40, 56));
  const init = serverRead.update(check.header);
  assert.equal(init.readUInt32LE(56), 0xefefefef);
  const request = serverRead.update(check.packet);
  assert.equal(request[0], 10);
  assert.equal(request.readUInt32LE(21), 0xbe7e8ef1);
  assert.deepEqual(request.subarray(25), check.nonce);
  assert.equal(request.readBigUInt64LE(9) & 3n, 0n);
  const reversed = Buffer.from(check.header).reverse();
  const serverWrite = createCipheriv("aes-256-ctr", reversed.subarray(8, 40), reversed.subarray(40, 56));
  const encrypted = serverWrite.update(Buffer.concat([Buffer.from([21]), reply(check.nonce)]));
  assert.equal(check.receive(encrypted.subarray(0, 1)), undefined);
  assert.equal(check.receive(encrypted.subarray(1, 17)), undefined);
  assert.equal(check.receive(encrypted.subarray(17)).nonceMatched, true);
});

test("resPQ rejects changed nonce, truncated envelopes, wrong constructors and invalid vectors", () => {
  const nonce = Buffer.alloc(16, 7);
  assert.throws(() => parseResPQ(reply(nonce), Buffer.alloc(16, 8)), /Nonce mismatch/);
  assert.throws(() => parseResPQ(reply(nonce).subarray(0, 40), nonce), /envelope/);
  for (const [offset, value, expected] of [[20, 0, /resPQ/], [68, 0, /vector/], [72, 65, /count/]]) {
    const message = reply(nonce);
    message.writeUInt32LE(value, offset);
    assert.throws(() => parseResPQ(message, nonce), expected);
  }
  const error = Buffer.alloc(4);
  error.writeInt32LE(-404);
  assert.throws(() => parseResPQ(error, nonce), /-404/);
});
