import { readFile, writeFile, mkdir, access } from "node:fs/promises";
import assert from "node:assert/strict";
import { TelegramClient, Api } from "teleproto";
import { StringSession } from "teleproto/sessions";
import { PromisedWebSockets } from "teleproto/extensions";
import { createRelayTransport } from "./relay-transport.mjs";
import { createTerminal } from "./terminal.mjs";
import { createVideoReader, abortable } from "./media.mjs";
import { benchmark } from "./benchmark.mjs";
import { channel } from "node:diagnostics_channel";
import { startPlayer } from "./player.mjs";
import { spawn } from "node:child_process";

const apiId = Number(process.env.TG_API_ID);
const apiHash = process.env.TG_API_HASH;
const native = process.argv.includes("--native");
// shortcut: this prototype uses the verified portable VLC version; update the path when upgrading it.
const nativePlayerPath = new URL("../.tools/vlc/vlc-3.0.23/vlc.exe", import.meta.url);
if (native) {
  if (process.platform !== "win32") throw new Error("当前原生播放入口仅支持 Windows");
  await access(nativePlayerPath);
}
if (!Number.isSafeInteger(apiId) || apiId <= 0 || !/^[a-f0-9]{32}$/i.test(apiHash ?? "")) {
  console.error("请在本机 .env 填写 TG_API_ID 和 TG_API_HASH，再运行 npm run speed。");
  process.exit(1);
}
if (!process.stdin.isTTY) {
  console.error("请在本机交互终端运行 npm run speed，验证码不要发到聊天里。");
  process.exit(1);
}
const token = (await readFile(".dev.vars", "utf8")).match(/^RELAY_TOKEN=(.+)$/m)?.[1].trim();
const { agent, RelayWebSocket, ips, attempts } = createRelayTransport(process.env.RELAY_URL, process.env.RELAY_IP, token);
PromisedWebSockets.webSocketImpl = RelayWebSocket;
const terminal = createTerminal();
const operation = new AbortController();
const cancel = () => operation.abort(new Error("用户取消测速"));
terminal.onCancel(cancel);
process.on("SIGINT", cancel);
const question = (label, secret = false) => terminal.question(label, secret, operation.signal);
const sockets = [];
const onConnect = ({ socket }) => sockets.push({ remoteIp: socket.remoteAddress });
channel("undici:client:connected").subscribe(onConnect);
const report = { checkedAt: new Date().toISOString(), status: "running", relay: process.env.RELAY_URL,
  proxy: false, publicIps: ips, sockets, connectionAttempts: attempts,
  scope: "same video, same first up-to-32-MiB interval, 512-KiB chunks; warm media connection; concurrent requests on one SDK media sender",
  order: [1, 2, 4], rounds: [], logoutConfirmed: false,
};
let authorized = false;
let player;
const play = process.argv.includes("--play");
if (play) report.scope = "local Range player with 4-request prefetch and up-to-8-MiB memory cache; no persisted video or account session";
const client = new TelegramClient(new StringSession(""), apiId, apiHash, {
  // The SDK needs a second attempt to follow PHONE_MIGRATE and resend on the account's DC.
  networkSocket: PromisedWebSockets, connectionRetries: 2, requestRetries: 2, reconnectRetries: 2,
  timeout: 10, retryDelay: 1000, floodSleepThreshold: 0,
  deviceModel: "TG Cine prototype", appVersion: "0.1",
});
client.setLogLevel("error");
try {
  await abortable(client.start({
    phoneNumber: () => question("Telegram 手机号（含国家区号，输入后按回车）："),
    phoneCode: () => question("Telegram 登录验证码（显示星号，输入后按回车）：", true),
    password: () => question("Telegram 二次验证密码（显示星号，输入后按回车）：", true),
    onError: error => { console.error(error.errorMessage ?? "登录失败"); return true; },
  }), operation.signal);
  authorized = true;
  console.log("登录成功；会话仅保存在内存，结束时会请求注销本次登录。");
  const dialogs = await abortable(client.getDialogs({ limit: 100 }), AbortSignal.any([operation.signal, AbortSignal.timeout(30000)]));
  dialogs.forEach((dialog, i) => console.log(`${i + 1}. ${dialog.title}`));
  const selection = Number(await question("选择测试群/频道序号："));
  if (!Number.isInteger(selection) || selection < 1 || selection > dialogs.length) throw new Error("无效会话序号");
  const entity = dialogs[selection - 1].entity;
  const videos = await abortable(client.getMessages(entity, { limit: 10, filter: new Api.InputMessagesFilterVideo() }),
    AbortSignal.any([operation.signal, AbortSignal.timeout(30000)]));
  if (!videos.length) throw new Error("最近没有可读取的视频，请选择另一个会话");
  videos.forEach((message, i) => console.log(`${i + 1}. 消息 ${message.id}，${Number(message.media.document.size) / 1048576} MiB`));
  const videoSelection = Number(await question("选择测试视频序号："));
  if (!Number.isInteger(videoSelection) || videoSelection < 1 || videoSelection > videos.length) throw new Error("无效视频序号");
  const message = videos[videoSelection - 1];
  const reader = createVideoReader(client, message, async () => {
    const fresh = await client.getMessages(entity, { ids: [message.id] });
    if (!fresh[0]?.media?.document) throw new Error("视频已删除或无法访问");
    return fresh[0];
  });
  const targetBytes = Math.min(32 * 1048576, reader.size);
  report.targetBytes = targetBytes;
  if (process.argv.includes("--check-recovery")) {
    console.log("开始媒体断线验证：预热后仅关闭本进程的媒体 WebSocket，再以 4 并发读取相同区间。不会更改网卡或系统网络。");
    await reader.read(0, operation.signal);
    const sender = await abortable(client.getSender(reader.dcId), AbortSignal.any([operation.signal, AbortSignal.timeout(30000)]));
    // shortcut: the pinned SDK exposes its socket here; recheck this access when upgrading teleproto.
    const socket = sender._connection?.socket?.client;
    assert.ok(socket, "无法定位已预热的媒体连接，停止故障注入");
    socket.close();
    const recovered = await benchmark(reader, targetBytes, 4, { signal: operation.signal });
    assert.notEqual(sender._connection?.socket?.client, socket, "未建立新媒体连接");
    report.mediaRecovery = { ok: true, scope: "deliberate media WebSocket closure, then a complete four-request sample; no OS network changes", ...recovered };
    console.log(`媒体连接已恢复，首片等待 ${recovered.firstByteMs} ms，${recovered.averageMiBps} MiB/s。`);
  }
  if (play) {
    player = await startPlayer(reader, message.media.document.mimeType);
    report.player = player.stats;
    report.status = "playing";
    await mkdir("results", { recursive: true });
    await writeFile("results/telegram-play-session.json", JSON.stringify(report, null, 2) + "\n");
    console.log(`本机播放入口：${player.url}`);
    console.log(`本机播放器流地址：${player.url}video`);
    if (process.platform === "win32") {
      if (native) {
        const { fileURLToPath } = await import("node:url");
        const vlc = spawn(fileURLToPath(nativePlayerPath), ["--no-one-instance", "--no-qt-recentplay", "--no-metadata-network-access", "--no-qt-privacy-ask", `${player.url}video`], { stdio: "ignore" });
        vlc.on("error", () => console.log("VLC 未能打开，请手动用本机播放器打开上方流地址。"));
      } else {
        const browser = spawn("rundll32.exe", ["url.dll,FileProtocolHandler", player.url], { windowsHide: true, stdio: "ignore" });
        browser.on("error", () => console.log("浏览器未自动打开，请复制上方地址到浏览器。"));
      }
    }
    await question("在播放器中播放并拖动。按回车或 Ctrl+C 结束本次播放并注销：");
  } else {
    console.log(`三轮各读取相同 ${targetBytes / 1048576} MiB，共约 ${3 * targetBytes / 1048576} MiB；视频不保存。Ctrl+C 可取消。`);
    const warmupStarted = performance.now();
    await abortable(reader.read(0, operation.signal), AbortSignal.any([operation.signal, AbortSignal.timeout(30000)]));
    report.warmupMs = Math.round(performance.now() - warmupStarted);
    for (const concurrency of report.order) {
      console.log(`开始 ${concurrency} 并发请求对照，每轮总时限 180 秒，单次请求时限 15 秒。`);
      let lastProgress = 0;
      const result = await benchmark(reader, targetBytes, concurrency, { signal: operation.signal,
        onProgress(bytes, elapsedMs) {
          if (bytes - lastProgress >= 4 * 1048576 || bytes === targetBytes) {
            console.log(`${concurrency} 并发：${(bytes / 1048576).toFixed(1)} MiB，平均 ${(bytes / 1048576 / (elapsedMs / 1000)).toFixed(2)} MiB/s`);
            lastProgress = bytes;
          }
        },
      });
      if (report.rounds.length) assert.equal(result.sampleFingerprint, report.rounds[0].sampleFingerprint, "三轮样本内容不一致");
      report.rounds.push(result);
      console.log(`${concurrency} 并发完成：${result.averageMiBps} MiB/s，分片 P50/P95 ${result.chunkP50Ms}/${result.chunkP95Ms} ms`);
    }
  }
  report.status = play ? (player.stats.errors ? "failed" : "ended") : "success";
} catch (error) {
  console.error(error.errorMessage ?? error.message);
  report.status = operation.signal.aborted ? "cancelled" : "failed";
  report.error = error.errorMessage ?? error.name;
  process.exitCode = 1;
} finally {
  terminal.close();
  if (player) await player.stop();
  if (authorized) {
    try {
      await client.invoke(new Api.auth.LogOut(), undefined, { timeout: 5000, maxRetryCount: 0 });
      report.logoutConfirmed = true;
    } catch {
      console.error("注销未确认；请在 Telegram 设置 → 设备中终止 TG Cine prototype 会话。");
    }
  }
  await client.destroy().catch(() => {});
  await agent.destroy();
  process.off("SIGINT", cancel);
  channel("undici:client:connected").unsubscribe(onConnect);
  report.finishedAt = new Date().toISOString();
  await mkdir("results", { recursive: true });
  const json = JSON.stringify(report, null, 2) + "\n";
  const reportName = play ? "telegram-play-session" : "telegram-speed-comparison";
  await writeFile(`results/${reportName}.json`, json);
  await writeFile(`results/${reportName}-${report.finishedAt.replace(/[:.]/g, "-")}.json`, json);
  if (!play) console.table(report.rounds.map(({ concurrency, averageMiBps, averageMbps, firstByteMs, chunkP50Ms, chunkP95Ms }) =>
    ({ concurrency, averageMiBps, averageMbps, firstByteMs, chunkP50Ms, chunkP95Ms })));
  console.log(`结果：${report.status}；注销确认：${report.logoutConfirmed}；报告 results/${reportName}.json`);
}
