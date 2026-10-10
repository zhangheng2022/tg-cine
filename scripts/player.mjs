import { createServer } from "node:http";
import { randomBytes } from "node:crypto";
import { once } from "node:events";
import { readFile } from "node:fs/promises";
import { CHUNK_SIZE, abortable } from "./media.mjs";

export function parseRange(header, size) {
  if (!header) return { start: 0, end: size - 1, partial: false };
  const match = /^bytes=(\d*)-(\d*)$/.exec(header);
  if (!match || (!match[1] && !match[2])) throw new Error("Invalid Range");
  const first = match[1] ? Number(match[1]) : undefined;
  const last = match[2] ? Number(match[2]) : undefined;
  if ([first, last].some(value => value !== undefined && !Number.isSafeInteger(value))) throw new Error("Invalid Range");
  const start = first === undefined ? Math.max(0, size - last) : first;
  const end = first === undefined || last === undefined ? size - 1 : Math.min(last, size - 1);
  if (start < 0 || start >= size || end < start) throw new Error("Unsatisfiable Range");
  return { start, end, partial: true };
}

export async function startPlayer(reader, mimeType = "video/mp4") {
  if (!Number.isSafeInteger(reader.size) || reader.size <= 0 || !/^video\/[a-z0-9.+-]+$/i.test(mimeType)) {
    throw new Error("无效播放器媒体配置");
  }
  const token = randomBytes(24).toString("base64url");
  const path = `/${token}`;
  const cache = new Map();
  const requests = new Set();
  const stats = { requests: 0, rangeRequests: 0, servedBytes: 0, errors: 0 };
  const browserScript = await readFile(new URL("./player-browser.js", import.meta.url));
  let origin;
  const server = createServer(async (request, response) => {
    response.setHeader("Cache-Control", "no-store");
    response.setHeader("Referrer-Policy", "no-referrer");
    response.setHeader("Cross-Origin-Resource-Policy", "same-origin");
    response.setHeader("X-Content-Type-Options", "nosniff");
    if (request.headers.host !== new URL(origin).host ||
        (request.headers.origin && request.headers.origin !== origin)) {
      response.writeHead(403).end(); return;
    }
    if (!["GET", "HEAD"].includes(request.method)) { response.writeHead(405, { Allow: "GET, HEAD" }).end(); return; }
    if (request.url === `${path}/`) {
      response.setHeader("Content-Security-Policy", "default-src 'none'; media-src 'self'; script-src 'self'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'");
      response.setHeader("Content-Type", "text/html; charset=utf-8");
      response.end(request.method === "HEAD" ? undefined : `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>TG Cine · 本机视频播放</title><style>body{margin:0;background:#111;color:#eee;font:16px system-ui;padding:24px}main{max-width:1100px;margin:auto}video{width:100%;max-height:80vh;background:#000}p{color:#bbb}a{color:#9dc8ff;overflow-wrap:anywhere}</style><main><h1>TG Cine · 本机视频播放</h1><video controls preload="metadata" controlslist="nodownload" src="${path}/video"></video><p id="status" role="status" aria-live="polite">正在加载视频信息…</p><p>VLC 网络串流地址（右键复制链接地址，粘贴到 VLC；不能使用此网页地址）：<a href="${path}/video">${origin}${path}/video</a></p><p>点击播放，可拖动进度。当前视频通过 Worker 中转，缓存仅保留在本机内存。返回测速终端按回车结束播放并注销。</p></main><script src="${path}/player.js" defer></script></html>`);
      return;
    }
    if (request.url === `${path}/player.js`) {
      response.setHeader("Content-Type", "text/javascript; charset=utf-8");
      response.end(request.method === "HEAD" ? undefined : browserScript); return;
    }
    if (request.url !== `${path}/video`) { response.writeHead(404).end(); return; }
    let range;
    try { range = parseRange(request.headers.range, reader.size); }
    catch { response.writeHead(416, { "Content-Range": `bytes */${reader.size}` }).end(); return; }
    if (requests.size >= 4) { response.writeHead(503, { "Retry-After": "1" }).end(); return; }
    const { start, end, partial } = range;
    response.setHeader("Content-Type", mimeType);
    response.setHeader("Accept-Ranges", "bytes");
    response.setHeader("Content-Length", end - start + 1);
    if (partial) response.setHeader("Content-Range", `bytes ${start}-${end}/${reader.size}`);
    response.statusCode = partial ? 206 : 200;
    if (request.method === "HEAD") { response.end(); return; }
    stats.requests++;
    if (partial) stats.rangeRequests++;
    const controller = new AbortController();
    requests.add(controller);
    const closed = () => controller.abort(new Error("播放请求已断开"));
    response.on("close", closed);
    const pending = [];
    let nextOffset = Math.floor(start / CHUNK_SIZE) * CHUNK_SIZE;
    function enqueue() {
      if (nextOffset > end) return;
      const offset = nextOffset;
      nextOffset += CHUNK_SIZE;
      const cached = cache.get(offset);
      const promise = abortable(cached ? Promise.resolve(cached) : reader.read(offset, controller.signal), controller.signal).then(data => {
        const expected = Math.min(CHUNK_SIZE, reader.size - offset);
        if (data.length !== expected) throw new Error("播放分片不完整");
        cache.delete(offset);
        cache.set(offset, data);
        if (cache.size > 16) cache.delete(cache.keys().next().value);
        return { data };
      }).catch(error => ({ error }));
      pending.push({ offset, promise });
    }
    try {
      for (let i = 0; i < 4; i++) enqueue();
      while (pending.length) {
        controller.signal.throwIfAborted();
        const { offset, promise } = pending.shift();
        const { data, error } = await abortable(promise, controller.signal);
        if (error) throw error;
        const slice = data.subarray(Math.max(0, start - offset), Math.min(data.length, end - offset + 1));
        const writable = response.write(slice);
        stats.servedBytes += slice.length;
        if (!writable) await abortable(once(response, "drain"), controller.signal);
        enqueue();
      }
      response.end();
    } catch {
      if (!controller.signal.aborted) stats.errors++;
      controller.abort(new Error("播放请求结束"));
      if (!response.headersSent) {
        response.removeHeader("Content-Length");
        response.removeHeader("Content-Range");
        response.setHeader("Content-Type", "text/plain; charset=utf-8");
        response.writeHead(502).end("Video read failed");
      }
      else response.destroy();
    } finally {
      await Promise.allSettled(pending.map(item => item.promise));
      response.off("close", closed);
      requests.delete(controller);
    }
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  origin = `http://127.0.0.1:${server.address().port}`;
  return { url: `${origin}${path}/`, stats, async stop() {
    for (const controller of requests) controller.abort(new Error("播放器已关闭"));
    const closed = new Promise(resolve => server.close(resolve));
    server.closeAllConnections();
    await closed;
    cache.clear();
  } };
}
