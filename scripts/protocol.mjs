import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

export function createProbe() {
  let init;
  do {
    init = randomBytes(64);
  } while (init[0] === 0xef || init.readUInt32LE(4) === 0 ||
    [0xdddddddd, 0xeeeeeeee, 0x54534f50, 0x20544547, 0x44414548, 0x4954504f, 0x02010316]
      .includes(init.readUInt32LE(0)));
  const reversed = Buffer.from(init).reverse();
  const encrypt = createCipheriv("aes-256-ctr", init.subarray(8, 40), init.subarray(40, 56));
  const decrypt = createDecipheriv("aes-256-ctr", reversed.subarray(8, 40), reversed.subarray(40, 56));
  init.fill(0xef, 56, 60);
  const header = Buffer.from(init);
  encrypt.update(init).copy(header, 56, 56, 64);
  const nonce = randomBytes(16);
  const message = Buffer.alloc(40);
  // Unencrypted MTProto envelope: auth_key_id, msg_id, body length, req_pq_multi, nonce.
  const ms = BigInt(Date.now());
  message.writeBigUInt64LE(((ms / 1000n << 32n) | (ms % 1000n << 32n) / 1000n) & ~3n, 8);
  message.writeUInt32LE(20, 16);
  message.writeUInt32LE(0xbe7e8ef1, 20);
  nonce.copy(message, 24);
  const packet = encrypt.update(Buffer.concat([Buffer.from([message.length / 4]), message]));
  let received = Buffer.alloc(0);
  return {
    header, packet, nonce,
    receive(bytes) {
      received = Buffer.concat([received, decrypt.update(bytes)]);
      if (received.length > 65536) throw new Error("Oversized handshake reply");
      if (received.length < 1) return;
      const prefix = received[0] === 0x7f ? 4 : 1;
      if (received[0] > 0x7f) throw new Error("Unexpected quick ACK");
      if (received.length < prefix) return;
      const size = (prefix === 1 ? received[0] : received.readUIntLE(1, 3)) * 4;
      if (size < 4 || size > 65536) throw new Error("Invalid handshake frame size");
      if (received.length < prefix + size) return;
      return parseResPQ(received.subarray(prefix, prefix + size), nonce);
    },
  };
}

export function parseResPQ(message, nonce) {
  if (message.length === 4) throw new Error(`Telegram transport error ${message.readInt32LE()}`);
  if (message.length < 76 || message.readBigUInt64LE(0) !== 0n ||
      message.readUInt32LE(16) !== message.length - 20) throw new Error("Invalid MTProto envelope");
  if ((message.readBigUInt64LE(8) & 1n) !== 1n) throw new Error("Invalid server message ID");
  const body = message.subarray(20);
  if (body.readUInt32LE(0) !== 0x05162463) throw new Error("Expected resPQ");
  if (!body.subarray(4, 20).equals(nonce)) throw new Error("Nonce mismatch");
  const pqLength = body[36];
  if (pqLength < 1 || pqLength > 8) throw new Error("Invalid pq length");
  const pq = body.subarray(37, 37 + pqLength);
  const vectorOffset = 36 + Math.ceil((1 + pqLength) / 4) * 4;
  if (body.length < vectorOffset + 8 || body.readUInt32LE(vectorOffset) !== 0x1cb5c415) {
    throw new Error("Invalid RSA fingerprint vector");
  }
  const count = body.readUInt32LE(vectorOffset + 4);
  if (count < 1 || count > 64 || body.length !== vectorOffset + 8 + count * 8) {
    throw new Error("Invalid RSA fingerprint count");
  }
  return {
    response: "resPQ", nonceMatched: true, bytes: message.length,
    pq: pq.toString("hex"), fingerprintCount: count,
    serverTime: new Date(Number(message.readBigUInt64LE(8) >> 32n) * 1000).toISOString(),
  };
}
