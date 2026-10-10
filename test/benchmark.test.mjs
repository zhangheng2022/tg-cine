import assert from "node:assert/strict";
import test from "node:test";
import { setTimeout as delay } from "node:timers/promises";
import { benchmark } from "../scripts/benchmark.mjs";
import { CHUNK_SIZE, abortable } from "../scripts/media.mjs";

test("1/2/4 requests cover the same interval exactly despite out-of-order completion", async () => {
  const size = CHUNK_SIZE * 3 + 17;
  const fingerprints = [];
  for (const concurrency of [1, 2, 4]) {
    let active = 0;
    let peak = 0;
    const offsets = [];
    const reader = { size, async read(offset) {
      offsets.push(offset);
      peak = Math.max(peak, ++active);
      await delay(4 - offset / CHUNK_SIZE);
      active--;
      return Buffer.alloc(Math.min(CHUNK_SIZE, size - offset), offset / CHUNK_SIZE);
    } };
    const result = await benchmark(reader, size, concurrency);
    assert.equal(result.bytes, size);
    assert.equal(peak, concurrency);
    assert.deepEqual(offsets.sort((a, b) => a - b), [0, CHUNK_SIZE, CHUNK_SIZE * 2, CHUNK_SIZE * 3]);
    assert.equal(result.chunks.at(-1).bytes, 17);
    fingerprints.push(result.sampleFingerprint);
  }
  assert.equal(new Set(fingerprints).size, 1);
});

test("hung reads time out, cancellation stops all workers, and short reads fail", async () => {
  const stalled = { size: CHUNK_SIZE * 4, read: () => new Promise(() => {}) };
  await assert.rejects(benchmark(stalled, stalled.size, 4, { timeoutMs: 20 }), /总时限/);
  const cancel = new AbortController();
  const work = benchmark(stalled, stalled.size, 4, { signal: cancel.signal });
  cancel.abort(new Error("cancelled"));
  await assert.rejects(work, /cancelled/);
  await assert.rejects(benchmark({ size: 100, read: async () => Buffer.alloc(99) }, 100, 1), /不完整/);
  await assert.rejects(benchmark(stalled, stalled.size, 8), /无效/);
  const preCancelled = new AbortController();
  preCancelled.abort(new Error("already cancelled"));
  await assert.rejects(abortable(Promise.reject(new Error("late error")), preCancelled.signal), /already cancelled/);
});
