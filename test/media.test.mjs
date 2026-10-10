import assert from "node:assert/strict";
import test from "node:test";
import { Api } from "teleproto";
import { createVideoReader, CHUNK_SIZE } from "../scripts/media.mjs";

function message(reference = "old", id = 1n) {
  return new Api.MessageMediaDocument({ document: new Api.Document({
    id, accessHash: 2n, fileReference: Buffer.from(reference), dcId: 2, size: BigInt(CHUNK_SIZE),
    date: 0, mimeType: "video/mp4", attributes: [],
  }) });
}
function file() {
  return new Api.upload.File({ type: new Api.storage.FileMp4(), mtime: 0, bytes: Buffer.alloc(CHUNK_SIZE) });
}

test("expired references refresh once for concurrent readers and preserve the selected video", async () => {
  let refreshes = 0;
  const client = { async invoke(request, dc, options) {
    assert.equal(dc, 2);
    assert.equal(options.timeout, 15000);
    assert.equal(options.maxRetryCount, 1);
    assert.equal(request.cdnSupported, undefined);
    assert.ok(request.getBytes().length > 0);
    if (request.location.fileReference.toString() === "old") throw { errorMessage: "FILE_REFERENCE_EXPIRED" };
    return file();
  } };
  const reader = createVideoReader(client, message(), async () => { refreshes++; return message("fresh"); });
  const signal = new AbortController().signal;
  const results = await Promise.all([reader.read(0, signal), reader.read(0, signal)]);
  assert.equal(refreshes, 1);
  assert.ok(results.every(data => data.length === CHUNK_SIZE));
  const changed = createVideoReader(client, message(), async () => message("fresh", 99n));
  await assert.rejects(changed.read(0, signal), /替换/);
});

test("media DC migration is bounded and malformed data fails", async () => {
  const seen = [];
  const reader = createVideoReader({ async invoke(_, dc) {
    seen.push(dc);
    if (dc === 2) throw { errorMessage: "FILE_MIGRATE_5", newDc: 5 };
    return file();
  } }, message(), async () => message());
  const signal = new AbortController().signal;
  assert.equal((await reader.read(0, signal)).length, CHUNK_SIZE);
  assert.deepEqual(seen, [2, 5]);
  assert.equal(reader.dcId, 5);
  await assert.rejects(reader.read(1, signal), /位置/);
  const short = createVideoReader({ async invoke() {
    return new Api.upload.File({ type: new Api.storage.FileMp4(), mtime: 0, bytes: Buffer.alloc(1) });
  } }, message(), async () => message());
  await assert.rejects(short.read(0, signal), /不完整/);
  const repeated = createVideoReader({ async invoke() { throw { errorMessage: "FILE_REFERENCE_EXPIRED" }; } },
    message(), async () => message("fresh"));
  await assert.rejects(repeated.read(0, signal), error => error.errorMessage === "FILE_REFERENCE_EXPIRED");
});
