import { Api } from "teleproto";
import { getFileInfo } from "teleproto/Utils.js";

export const CHUNK_SIZE = 512 * 1024;

export function abortable(promise, signal) {
  return new Promise((resolve, reject) => {
    const aborted = () => reject(signal.reason);
    if (signal.aborted) aborted();
    else signal.addEventListener("abort", aborted, { once: true });
    Promise.resolve(promise).then(resolve, reject).finally(() => signal.removeEventListener("abort", aborted));
  });
}

export function createVideoReader(client, message, refresh) {
  let info = getFileInfo(message);
  const size = Number(info.size);
  const documentId = info.location.id.toString();
  if (!Number.isSafeInteger(size) || size <= 0) throw new Error("无效视频大小");
  let refreshing;
  return { size, get dcId() { return info.dcId; }, async read(offset, signal) {
    signal.throwIfAborted();
    if (!Number.isSafeInteger(offset) || offset < 0 || offset >= size || offset % CHUNK_SIZE !== 0) {
      throw new Error("无效视频分片位置");
    }
    let refreshed = false;
    let migrated = false;
    for (;;) {
      signal.throwIfAborted();
      try {
        // CDN support stays disabled until a CDN transport and hash verification are implemented.
        const result = await client.invoke(new Api.upload.GetFile({
          location: info.location, offset: BigInt(offset), limit: CHUNK_SIZE, precise: true,
        }), info.dcId, { abortSignal: signal, timeout: 15000, maxRetryCount: 1 });
        if (!(result instanceof Api.upload.File)) throw new Error("不支持的媒体返回类型或 CDN 重定向");
        const expected = Math.min(CHUNK_SIZE, size - offset);
        if (result.bytes.length !== expected) throw new Error("视频分片读取不完整");
        return Buffer.from(result.bytes);
      } catch (error) {
        if (!migrated && /^FILE_MIGRATE_/.test(error.errorMessage ?? "") &&
            Number.isInteger(error.newDc) && error.newDc >= 1 && error.newDc <= 5) {
          migrated = true;
          info = { ...info, dcId: error.newDc };
          continue;
        }
        if (!refreshed && /^FILE_REFERENCE_(EXPIRED|INVALID)$/.test(error.errorMessage ?? "")) {
          refreshed = true;
          refreshing ??= Promise.resolve().then(refresh).then(fresh => {
            const updated = getFileInfo(fresh);
            if (updated.location.id.toString() !== documentId || Number(updated.size) !== size) {
              throw new Error("视频已被替换，停止读取");
            }
            info = updated;
          }).finally(() => { refreshing = undefined; });
          await abortable(refreshing, signal);
          continue;
        }
        throw error;
      }
    }
  } };
}
