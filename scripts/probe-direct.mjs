import { readFile, writeFile, mkdir } from "node:fs/promises";
import { channel } from "node:diagnostics_channel";
import { createRelayTransport } from "./relay-transport.mjs";
import { probe } from "./probe.mjs";

const token = (await readFile(".dev.vars", "utf8")).match(/^RELAY_TOKEN=(.+)$/m)?.[1].trim();
const relayUrl = process.env.RELAY_URL;
const relayIp = process.env.RELAY_IP;
const { agent, RelayWebSocket, ips, attempts } = createRelayTransport(relayUrl, relayIp, token);
const sockets = [];
const onConnect = ({ socket }) => sockets.push({ remoteIp: socket.remoteAddress });
channel("undici:client:connected").subscribe(onConnect);
try {
  const results = await Promise.all([1, 2, 3, 4, 5].map(async dc => ({ dc,
    ...await probe(`${relayUrl.replace(/\/$/, "")}/dc/${dc}`, token, 12000, RelayWebSocket),
  })));
  const report = { checkedAt: new Date().toISOString(), mode: "direct-custom-domain",
    proxy: false, publicIps: ips, connectionAttempts: attempts, sockets, results };
  await mkdir("results", { recursive: true });
  await writeFile("results/custom-domain-no-proxy.json", JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify(report, null, 2));
  if (results.some(result => !result.ok)) process.exitCode = 1;
} finally {
  channel("undici:client:connected").unsubscribe(onConnect);
  await agent.destroy();
}
