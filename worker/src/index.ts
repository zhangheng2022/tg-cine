import { errorResponse, PROTOCOL_VERSION } from './protocol';
import { handleTunnel } from './tunnel';

export default {
	async fetch(request, env, ctx): Promise<Response> {
		const path = new URL(request.url).pathname;
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
		return handleTunnel(request, env, ctx);
	},
} satisfies ExportedHandler<Env>;
