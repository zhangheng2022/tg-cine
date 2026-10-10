import { authorize } from './auth';
import { errorResponse, readTargetId } from './protocol';
import { resolveTarget } from './targets';

export async function handleTunnel(request: Request, env: Env): Promise<Response> {
	const authError = await authorize(request, env.RELAY_TOKEN);
	if (authError) return authError;
	const targetId = readTargetId(new URL(request.url));
	if (targetId instanceof Response) return targetId;
	const target = resolveTarget(targetId, env.RELAY_TARGETS);
	if (target instanceof Response) return target;
	if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') {
		return errorResponse(426, 'WEBSOCKET_REQUIRED', { Upgrade: 'websocket' });
	}
	return errorResponse(501, 'TUNNEL_NOT_IMPLEMENTED');
}
