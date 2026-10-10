import assert from "node:assert/strict";
import test from "node:test";
import { PassThrough, Writable } from "node:stream";
import { createTerminal } from "../scripts/terminal.mjs";

test("secret input shows stars, supports backspace/paste, and never echoes the secret", async () => {
  const input = new PassThrough();
  let display = "";
  const stdout = new Writable({ write(chunk, _, callback) { display += chunk.toString(); callback(); } });
  stdout.isTTY = true;
  stdout.columns = 100;
  const terminal = createTerminal(input, stdout);
  try {
    const answer = terminal.question("Code: ", true);
    input.write("12345");
    assert.ok(display.includes("Code: *****"));
    input.write("\x7f");
    assert.ok(display.endsWith("Code: ****\x1b[K"));
    input.write("67\r");
    assert.equal(await answer, "123467");
    assert.ok(!display.includes("12345") && !display.includes("123467"));
    const phone = terminal.question("Phone: ");
    input.write("+10000000000\r");
    assert.equal(await phone, "+10000000000");
    assert.ok(display.includes("+10000000000"));
  } finally { terminal.close(); input.destroy(); stdout.destroy(); }
});

test("Ctrl+C aborts a pending secret prompt without revealing input", async () => {
  const input = new PassThrough();
  let display = "";
  const stdout = new Writable({ write(chunk, _, cb) { display += chunk.toString(); cb(); } });
  stdout.isTTY = true;
  const terminal = createTerminal(input, stdout);
  const controller = new AbortController();
  terminal.onCancel(() => controller.abort());
  try {
    const answer = terminal.question("Secret: ", true, controller.signal);
    input.write("secret\x03");
    await assert.rejects(answer, { name: "AbortError" });
    assert.ok(!display.includes("secret"));
  } finally { terminal.close(); input.destroy(); stdout.destroy(); }
});
