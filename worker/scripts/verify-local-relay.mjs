import { strict as assert } from 'node:assert';
import { randomBytes } from 'node:crypto';
import { mkdir, mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { createServer } from 'node:net';
import { resolve, join, dirname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

const root = resolve(import.meta.dirname, '..');
const runtimeDir = join(root, '.wrangler');
await mkdir(runtimeDir, { recursive: true });
const temp = await mkdtemp(join(runtimeDir, 'relay-proof-'));
const configPath = join(temp, 'wrangler.json');
const tokenPath = join(temp, 'token.txt');
const clients = new Set();
const echo = createServer((socket) => {
	clients.add(socket);
	socket.once('close', () => clients.delete(socket));
	socket.on('error', () => socket.destroy());
	socket.pipe(socket);
});
let worker;
let dart;
let deadline;
try {
	await new Promise((resolve) => echo.listen(0, '127.0.0.1', resolve));
	const echoPort = echo.address().port;
	const reservation = createServer();
	await new Promise((resolve) => reservation.listen(0, '127.0.0.1', resolve));
	const workerPort = reservation.address().port;
	await new Promise((resolve) => reservation.close(resolve));
	const token = randomBytes(32).toString('base64url');
	await writeFile(tokenPath, token);
	await writeFile(
		configPath,
		JSON.stringify({
			name: 'tg-cine-local-relay-proof',
			main: join(root, 'src/index.ts'),
			compatibility_date: '2026-10-10',
			compatibility_flags: ['nodejs_compat'],
			vars: {
				RELAY_ENABLED: 'true',
				RELAY_TOKEN: token,
				RELAY_TARGETS: JSON.stringify({ local_echo: { hostname: '127.0.0.1', port: echoPort } }),
			},
		}),
	);
	worker = spawn(
		process.execPath,
		[join(root, 'node_modules/wrangler/bin/wrangler.js'), 'dev', '--local', '--config', configPath, '--port', String(workerPort)],
		{
			cwd: root,
			stdio: ['ignore', 'ignore', 'ignore'],
			env: { ...process.env, WRANGLER_SEND_METRICS: 'false' },
		},
	);
	let ready = false;
	for (let attempt = 0; attempt < 100; attempt++) {
		if (worker.exitCode !== null) throw new Error('Local Worker exited before startup');
		const response = await fetch(`http://127.0.0.1:${workerPort}/health`, { signal: AbortSignal.timeout(1000) }).catch(() => null);
		if (response?.ok) {
			ready = (await response.json()).capabilities.tunnel === true;
			break;
		}
		await delay(100);
	}
	assert(ready, 'Local Worker did not start');
	const packageConfig = JSON.parse(await readFile(resolve(root, '../app/.dart_tool/package_config.json'), 'utf8'));
	const sdk = dirname(dirname(fileURLToPath(packageConfig.packages.find((entry) => entry.name === 'flutter').rootUri)));
	const dartCommand = join(sdk, 'bin/cache/dart-sdk/bin', process.platform === 'win32' ? 'dart.exe' : 'dart');
	dart = spawn(dartCommand, ['run', 'tool/verify_relay.dart', String(workerPort), String(echoPort), tokenPath], {
		cwd: resolve(root, '../app'),
		stdio: ['ignore', 'pipe', 'pipe'],
	});
	let output = '';
	dart.stdout.on('data', (chunk) => {
		output += chunk;
	});
	dart.stderr.on('data', (chunk) => {
		output += chunk;
	});
	const result = await Promise.race([
		new Promise((resolve, reject) => {
			dart.once('error', reject);
			dart.once('exit', (code) => resolve(code));
		}),
		new Promise((_, reject) => {
			deadline = setTimeout(() => reject(new Error(`Local relay proof timed out: ${output.replaceAll(token, '[redacted]')}`)), 30_000);
		}),
	]);
	assert.equal(result, 0, output.replaceAll(token, '[redacted]'));
	assert.match(output, /Verified 1048576 ordered bytes/);
	console.log(output.trim());
} finally {
	clearTimeout(deadline);
	for (const child of [dart, worker]) {
		if (child && child.exitCode === null) {
			const exited = new Promise((resolve) => child.once('exit', resolve));
			child.kill();
			await exited;
		}
	}
	for (const socket of clients) socket.destroy();
	await new Promise((resolve) => echo.close(resolve));
	assert(resolve(temp).startsWith(`${runtimeDir}${sep}relay-proof-`), 'Cleanup must remain in the generated local fixture directory');
	await rm(temp, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 });
}
