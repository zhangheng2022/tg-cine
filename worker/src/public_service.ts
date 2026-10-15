import { errorResponse, PROTOCOL_VERSION } from './protocol';
import { getTelegramPolicy } from './targets';
import { DEVICE_DAILY_BYTES, GLOBAL_DAILY_BYTES, MAX_DEVICE_CONNECTIONS } from './public_access';
import type { PublicSession } from './public_access';

const encoder = new TextEncoder();
const pattern = /^([ar])\.([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.([A-Za-z0-9_-]{43})\.([A-Za-z0-9_-]{43})$/;
const encode = (bytes: Uint8Array) =>
	btoa(String.fromCharCode(...bytes))
		.replaceAll('+', '-')
		.replaceAll('/', '_')
		.replace(/=+$/, '');
const decode = (value: string) =>
	Uint8Array.from(atob(value.replaceAll('-', '+').replaceAll('_', '/') + '='), (letter) => letter.charCodeAt(0));

async function key(secret: string): Promise<CryptoKey> {
	return crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}

export async function digest(value: string): Promise<string> {
	return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value))), (byte) =>
		byte.toString(16).padStart(2, '0'),
	).join('');
}

async function mint(type: 'a' | 'r', id: string, secret: string): Promise<string> {
	const value = `${type}.${id}.${encode(crypto.getRandomValues(new Uint8Array(32)))}`;
	const signature = new Uint8Array(await crypto.subtle.sign('HMAC', await key(secret), encoder.encode(value)));
	return `${value}.${encode(signature)}`;
}

async function readToken(request: Request, env: Env, type: 'a' | 'r'): Promise<{ id: string; hash: string } | null> {
	const token = /^Bearer ([^\s]{1,160})$/i.exec(request.headers.get('Authorization') ?? '')?.[1];
	const match = token?.match(pattern);
	if (!token || !match || match[1] !== type) return null;
	const unsigned = token.slice(0, token.lastIndexOf('.'));
	if (!(await crypto.subtle.verify('HMAC', await key(env.PUBLIC_SIGNING_KEY), decode(match[4]), encoder.encode(unsigned)))) return null;
	return { id: match[2], hash: await digest(token) };
}

function unavailable(env: Env): Response | null {
	return env.PUBLIC_SERVICE_ENABLED !== 'true' || env.RELAY_ENABLED !== 'true' || !/^[a-f0-9]{64}$/.test(env.PUBLIC_SIGNING_KEY ?? '')
		? errorResponse(503, 'PUBLIC_SERVICE_UNAVAILABLE', { 'Retry-After': '60' })
		: null;
}

export type PublicAccess = { session: DurableObjectStub<PublicSession>; hash: string };

async function rate(env: Env, key: string): Promise<Response | null> {
	return (await env.PUBLIC_REQUESTS.limit({ key })).success ? null : errorResponse(429, 'REQUEST_LIMIT', { 'Retry-After': '60' });
}

export async function authenticatePublic(request: Request, env: Env): Promise<PublicAccess | Response> {
	const disabled = unavailable(env);
	if (disabled) return disabled;
	const token = await readToken(request, env, 'a');
	if (!token) return errorResponse(401, 'UNAUTHORIZED', { 'WWW-Authenticate': 'Bearer' });
	const limited = await rate(env, `device:${token.id}`);
	if (limited) return limited;
	const session = env.PUBLIC_SESSIONS.getByName(token.id);
	if (!(await session.authenticate(token.hash))) return errorResponse(401, 'UNAUTHORIZED', { 'WWW-Authenticate': 'Bearer' });
	return { session, hash: token.hash };
}

export async function reservePublic(access: PublicAccess, env: Env): Promise<((bytes: number) => Promise<void>) | Response> {
	const id = crypto.randomUUID();
	const local = await access.session.reserve(access.hash, id);
	if (local === 'unauthorized') return errorResponse(401, 'UNAUTHORIZED');
	if (local === 'limited') return errorResponse(429, 'DEVICE_LIMIT', { 'Retry-After': '60' });
	const budget = env.PUBLIC_BUDGET.getByName('daily-budget');
	if (!(await budget.reserve(id))) {
		await access.session.settle(id, 0);
		return errorResponse(429, 'SERVICE_LIMIT', { 'Retry-After': '60' });
	}
	// Unsettled/expired reservations remain fully charged, including after process loss.
	return async (bytes) => {
		await Promise.all([access.session.settle(id, bytes), budget.settle(id, bytes)]);
	};
}

async function emptyBody(request: Request): Promise<boolean> {
	if (request.headers.get('Content-Type')?.split(';')[0].trim() !== 'application/json' || !request.body) return false;
	const reader = request.body.getReader();
	let body = '';
	let size = 0;
	const decoder = new TextDecoder('utf-8', { fatal: true, ignoreBOM: false });
	try {
		while (true) {
			const { value, done } = await reader.read();
			if (done) break;
			size += value.byteLength;
			if (size > 1024) return false;
			body += decoder.decode(value, { stream: true });
		}
		body += decoder.decode();
		const value: unknown = JSON.parse(body);
		return value !== null && typeof value === 'object' && !Array.isArray(value) && Object.keys(value).length === 0;
	} catch {
		return false;
	} finally {
		await reader.cancel();
	}
}

export async function handlePublic(request: Request, env: Env): Promise<Response> {
	const url = new URL(request.url);
	const config = url.pathname === '/v1/config';
	if (request.method !== (config ? 'GET' : 'POST')) return errorResponse(405, 'METHOD_NOT_ALLOWED', { Allow: config ? 'GET' : 'POST' });
	if (url.search) return errorResponse(400, 'INVALID_REQUEST');
	const disabled = unavailable(env);
	if (disabled) return disabled;
	if (config || url.pathname === '/v1/devices') {
		const ip = request.headers.get('CF-Connecting-IP');
		if (!ip || ip.length > 64) return errorResponse(400, 'CLIENT_ADDRESS_REQUIRED');
		const limited = await rate(env, `bootstrap:${await digest(ip)}`);
		if (limited) return limited;
	}
	const headers = { 'Cache-Control': 'no-store' };
	if (config) {
		const origin = new URL(env.PUBLIC_ORIGIN);
		if (origin.protocol !== 'https:' || origin.origin !== env.PUBLIC_ORIGIN) return errorResponse(503, 'PUBLIC_SERVICE_UNAVAILABLE');
		const targetPolicy = await getTelegramPolicy();
		if (targetPolicy instanceof Response) return targetPolicy;
		return Response.json(
			{
				protocolVersion: PROTOCOL_VERSION,
				relay: `${env.PUBLIC_ORIGIN.replace('https:', 'wss:')}/v1/tunnel`,
				targetPolicy,
				limits: {
					deviceDailyBytes: DEVICE_DAILY_BYTES,
					serviceDailyBytes: GLOBAL_DAILY_BYTES,
					connections: MAX_DEVICE_CONNECTIONS,
				},
			},
			{ headers },
		);
	}
	if (!(await emptyBody(request))) return errorResponse(400, 'INVALID_REQUEST');
	if (url.pathname === '/v1/devices') {
		const id = crypto.randomUUID();
		const refreshToken = await mint('r', id, env.PUBLIC_SIGNING_KEY);
		const accessToken = await mint('a', id, env.PUBLIC_SIGNING_KEY);
		const expiresAt = await env.PUBLIC_SESSIONS.getByName(id).enroll(await digest(refreshToken), await digest(accessToken));
		return Response.json({ accessToken, refreshToken, expiresAt }, { status: 201, headers });
	}
	const token = await readToken(request, env, 'r');
	if (!token) return errorResponse(401, 'UNAUTHORIZED');
	const limited = await rate(env, `device:${token.id}`);
	if (limited) return limited;
	const session = env.PUBLIC_SESSIONS.getByName(token.id);
	if (url.pathname === '/v1/devices/revoke') {
		return (await session.revoke(token.hash)) ? new Response(null, { status: 204, headers }) : errorResponse(401, 'UNAUTHORIZED');
	}
	const accessToken = await mint('a', token.id, env.PUBLIC_SIGNING_KEY);
	const expiresAt = await session.refresh(token.hash, await digest(accessToken));
	return expiresAt === null ? errorResponse(401, 'UNAUTHORIZED') : Response.json({ accessToken, expiresAt }, { headers });
}
