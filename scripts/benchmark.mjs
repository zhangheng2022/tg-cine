import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { abortable, CHUNK_SIZE } from "./media.mjs";

export async function benchmark(reader, targetBytes, concurrency, { signal, timeoutMs = 180000, onProgress = () => {} } = {}) {
  if (!Number.isSafeInteger(targetBytes) || targetBytes <= 0 || targetBytes > reader.size ||
      ![1, 2, 4].includes(concurrency) || !Number.isSafeInteger(timeoutMs) || timeoutMs <= 0) {
    throw new Error("无效测速参数");
  }
  const controller = new AbortController();
  const deadline = setTimeout(() => controller.abort(new Error("测速超过总时限")), timeoutMs);
  const activeSignal = signal ? AbortSignal.any([signal, controller.signal]) : controller.signal;
  const started = performance.now();
  let nextOffset = 0;
  let bytes = 0;
  let firstByteMs;
  const chunks = [];
  const hashes = [];
  const workers = Array.from({ length: concurrency }, async () => {
    while (nextOffset < targetBytes) {
      activeSignal.throwIfAborted();
      const offset = nextOffset;
      nextOffset += CHUNK_SIZE;
      const requestStarted = performance.now();
      const data = await abortable(reader.read(offset, activeSignal), activeSignal);
      const expected = Math.min(CHUNK_SIZE, targetBytes - offset);
      if (data.length < expected) throw new Error("分片读取不完整，测速失败");
      const sample = data.subarray(0, expected);
      firstByteMs ??= performance.now() - started;
      bytes += sample.length;
      hashes[offset / CHUNK_SIZE] = createHash("sha256").update(sample).digest();
      chunks.push({ offset, bytes: sample.length, elapsedMs: Math.round(performance.now() - requestStarted) });
      onProgress(bytes, performance.now() - started);
    }
  });
  try {
    await Promise.all(workers);
    const elapsedMs = performance.now() - started;
    assert.equal(bytes, targetBytes, "读取不完整，未生成成功测速结果");
    assert.ok(firstByteMs !== undefined && elapsedMs > 0);
    const fingerprint = createHash("sha256");
    hashes.forEach(hash => fingerprint.update(hash));
    const times = chunks.map(chunk => chunk.elapsedMs).sort((a, b) => a - b);
    return { concurrency, bytes, elapsedMs: Math.round(elapsedMs), firstByteMs: Math.round(firstByteMs),
      averageMiBps: Number((bytes / 1048576 / (elapsedMs / 1000)).toFixed(3)),
      averageMbps: Number((bytes * 8 / 1000000 / (elapsedMs / 1000)).toFixed(3)),
      chunkP50Ms: times[Math.ceil(times.length * 0.5) - 1], chunkP95Ms: times[Math.ceil(times.length * 0.95) - 1],
      sampleFingerprint: fingerprint.digest("hex"), chunks: chunks.sort((a, b) => a.offset - b.offset),
    };
  } catch (error) {
    controller.abort(error);
    await Promise.allSettled(workers);
    throw error;
  } finally { clearTimeout(deadline); }
}
