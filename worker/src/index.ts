import { errorResponse, PROTOCOL_VERSION } from './protocol';
import { handleTunnel } from './tunnel';
import { handlePublic } from './public_service';
export { PublicSession, PublicBudget } from './public_access';

export default {
	async fetch(request, env, ctx): Promise<Response> {
		const path = new URL(request.url).pathname;
		if (['/v1/config', '/v1/devices', '/v1/devices/refresh', '/v1/devices/revoke'].includes(path)) {
			try {
				return await handlePublic(request, env);
			} catch {
				return errorResponse(503, 'PUBLIC_SERVICE_UNAVAILABLE');
			}
		}
		if (path !== '/health' && path !== '/v1/tunnel') {
			return errorResponse(404, 'NOT_FOUND');
		}
		if (request.method !== 'GET') {
			return errorResponse(405, 'METHOD_NOT_ALLOWED', { Allow: 'GET' });
		}
		if (path === '/health') {
			return Response.json(
				{
					service: 'tg-cine-worker',
					status: 'ok',
					protocolVersion: PROTOCOL_VERSION,
					capabilities: { tunnel: env.RELAY_ENABLED === 'true' },
				},
				{ headers: { 'Cache-Control': 'no-store' } },
			);
		}
		try {
			return await handleTunnel(request, env, ctx);
		} catch {
			return errorResponse(503, 'SERVICE_UNAVAILABLE');
		}
	},
} satisfies ExportedHandler<Env>;
