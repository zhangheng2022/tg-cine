import { createInterface } from "node:readline/promises";
import { Writable } from "node:stream";

export function createTerminal(input = process.stdin, stdout = process.stdout) {
  let muted = false;
  const output = new Writable({ write(chunk, encoding, callback) {
    if (!muted) stdout.write(chunk, encoding);
    callback();
  } });
  output.isTTY = stdout.isTTY;
  output.columns = stdout.columns;
  const terminal = createInterface({ input, output, terminal: true });
  return {
    async question(label, secret = false, signal) {
      stdout.write(label);
      muted = secret;
      const feedback = (_, key) => {
        if (key?.name !== "return" && key?.name !== "enter") {
          stdout.write(`\r${label}${"*".repeat(terminal.line.length)}\x1b[K`);
        }
      };
      if (secret) input.on("keypress", feedback);
      try { return (await terminal.question("", { signal })).trim(); }
      finally {
        input.off("keypress", feedback);
        muted = false;
        if (secret) stdout.write("\n");
      }
    },
    onCancel(callback) { terminal.on("SIGINT", callback); },
    close() { terminal.close(); },
  };
}
