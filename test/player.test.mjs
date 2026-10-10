import assert from "node:assert/strict";
import test from "node:test";
import { parseRange, startPlayer } from "../scripts/player.mjs";
import { CHUNK_SIZE } from "../scripts/media.mjs";
import { get } from "node:http";
import { readFile } from "node:fs/promises";
import { runInNewContext } from "node:vm";

test("Range supports bounded/open/suffix intervals and rejects invalid or multiple ranges", () => {
  assert.deepEqual(parseRange(undefined, 100), { start: 0, end: 99, partial: false });
  assert.deepEqual(parseRange("bytes=4-12", 100), { start: 4, end: 12, partial: true });
  assert.deepEqual(parseRange("bytes=90-200", 100), { start: 90, end: 99, partial: true });
  assert.deepEqual(parseRange("bytes=90-", 100), { start: 90, end: 99, partial: true });
  assert.deepEqual(parseRange("bytes=-7", 100), { start: 93, end: 99, partial: true });
  for (const range of ["bytes=100-", "bytes=20-10", "bytes=-0", "bytes=-", "bytes=0-1,4-5", "bytes=9007199254740992-"]) {
    assert.throws(() => parseRange(range, 100));
  }
});

test("local player serves exact seek bytes, HEAD, cache, and rejects unauthorized access", async () => {
  const content = Buffer.alloc(CHUNK_SIZE * 3 + 19);
  for (let i = 0; i < content.length; i++) content[i] = i % 251;
  const offsets = [];
  const player = await startPlayer({ size: content.length, async read(offset) {
    offsets.push(offset);
    return content.subarray(offset, offset + CHUNK_SIZE);
  } });
  try {
    const video = `${player.url}video`;
    const page = await fetch(player.url);
    assert.equal(page.status, 200);
    const html = await page.text();
    assert.match(html, /<video controls/);
    assert.equal(new URL(html.match(/<a href="([^"]+)"/)[1], player.url).href, video);
    assert.match(page.headers.get("content-security-policy"), /script-src 'self'/);
    const script = await fetch(`${player.url}player.js`);
    assert.equal(script.status, 200);
    assert.match(script.headers.get("content-type"), /javascript/);
    const head = await fetch(video, { method: "HEAD", headers: { Range: "bytes=0-9" } });
    assert.equal(head.status, 206);
    assert.equal(head.headers.get("content-length"), "10");
    assert.equal(offsets.length, 0);
    const start = CHUNK_SIZE - 11;
    const end = CHUNK_SIZE + 23;
    const range = await fetch(video, { headers: { Range: `bytes=${start}-${end}` } });
    assert.equal(range.status, 206);
    assert.equal(range.headers.get("content-range"), `bytes ${start}-${end}/${content.length}`);
    assert.deepEqual(Buffer.from(await range.arrayBuffer()), content.subarray(start, end + 1));
    assert.deepEqual(offsets, [0, CHUNK_SIZE]);
    const cached = await fetch(video, { headers: { Range: `bytes=${start}-${end}` } });
    await cached.arrayBuffer();
    assert.equal(offsets.length, 2);
    const suffix = await fetch(video, { headers: { Range: "bytes=-7" } });
    assert.deepEqual(Buffer.from(await suffix.arrayBuffer()), content.subarray(-7));
    assert.equal((await fetch(video, { headers: { Range: "bytes=999999999-" } })).status, 416);
    assert.equal((await fetch(video, { headers: { Origin: "https://attacker.example" } })).status, 403);
    const badHost = await new Promise((resolve, reject) => get(video, { headers: { Host: "attacker.example" } }, response => {
      response.resume();
      response.on("end", () => resolve(response.statusCode));
    }).on("error", reject));
    assert.equal(badHost, 403);
    assert.equal((await fetch(new URL("/video", player.url))).status, 404);
    assert.equal((await fetch(video, { method: "POST" })).status, 405);
    assert.equal(player.stats.errors, 0);
    assert.equal(player.stats.rangeRequests, 3);
    const full = await fetch(video);
    assert.equal(full.status, 200);
    assert.deepEqual(Buffer.from(await full.arrayBuffer()), content);
  } finally { await player.stop(); }
});

test("browser warns about audio-only playback and distinguishes read and decode failures", async () => {
  const events = new Map();
  const status = { textContent: "正在加载视频信息…" };
  const video = { readyState: 1, videoWidth: 0, videoHeight: 0, paused: true,
    addEventListener(name, callback) { events.set(name, callback); } };
  runInNewContext(await readFile(new URL("../scripts/player-browser.js", import.meta.url), "utf8"), {
    document: { querySelector: () => video, getElementById: () => status },
  });
  assert.equal(status.textContent, "正在加载视频信息…");
  video.readyState = 4;
  video.paused = false;
  events.get("playing")();
  assert.match(status.textContent, /HEVC\/H.265/);
  video.videoWidth = 1920; video.videoHeight = 1080;
  events.get("playing")();
  assert.equal(status.textContent, "正在播放。");
  video.error = { code: 2 }; events.get("error")();
  assert.match(status.textContent, /读取失败/);
  video.error = { code: 3 }; events.get("error")();
  assert.match(status.textContent, /解码失败/);
});

test("player aborts active reads on stop and sends a bounded error for bad media", async () => {
  const bad = await startPlayer({ size: 100, read: async () => Buffer.alloc(1) });
  try {
    const response = await fetch(`${bad.url}video`);
    assert.equal(response.status, 502);
    assert.equal(await response.text(), "Video read failed");
    assert.equal(bad.stats.errors, 1);
  } finally { await bad.stop(); }
  const stalled = await startPlayer({ size: CHUNK_SIZE * 4, read: () => new Promise(() => {}) });
  const response = fetch(`${stalled.url}video`).catch(error => error);
  await new Promise(resolve => setTimeout(resolve, 20));
  await stalled.stop();
  assert.ok(await response instanceof Error);
});

test("memory cache evicts old chunks after its fixed 8-MiB budget", async () => {
  const reads = [];
  const player = await startPlayer({ size: CHUNK_SIZE * 18, async read(offset) {
    reads.push(offset);
    return Buffer.alloc(CHUNK_SIZE);
  } });
  try {
    const video = `${player.url}video`;
    const response = await fetch(video, { headers: { Range: `bytes=0-${CHUNK_SIZE * 17 - 1}` } });
    assert.equal((await response.arrayBuffer()).byteLength, CHUNK_SIZE * 17);
    assert.equal(reads.length, 17);
    const evicted = await fetch(video, { headers: { Range: "bytes=0-0" } });
    assert.equal((await evicted.arrayBuffer()).byteLength, 1);
    assert.equal(reads.length, 18);
    assert.equal(reads.at(-1), 0);
  } finally { await player.stop(); }
});

test("overlapping metadata and seek requests have four slots and a bounded limit", async () => {
  const player = await startPlayer({ size: CHUNK_SIZE * 4, read: () => new Promise(() => {}) });
  const requests = [];
  const cancels = [];
  try {
    for (let i = 0; i < 4; i++) {
      const controller = new AbortController(); cancels.push(controller);
      requests.push(fetch(`${player.url}video`, { signal: controller.signal }).catch(error => error));
    }
    for (let tries = 0; player.stats.requests < 4 && tries < 100; tries++) await new Promise(resolve => setTimeout(resolve, 5));
    assert.equal(player.stats.requests, 4);
    assert.equal((await fetch(`${player.url}video`)).status, 503);
  } finally {
    cancels.forEach(controller => controller.abort());
    await player.stop();
    await Promise.all(requests);
  }
});
