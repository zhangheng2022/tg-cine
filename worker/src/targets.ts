import { errorResponse } from './protocol';

export interface RelayTarget {
	hostname: string;
	port: number;
}

export function resolveTarget(targetId: string, config: string): RelayTarget | Response {
	let targets: unknown;
	try {
		targets = JSON.parse(config);
	} catch {
		return errorResponse(503, 'TARGETS_NOT_CONFIGURED');
	}
	if (targets === null || typeof targets !== 'object' || Array.isArray(targets)) {
		return errorResponse(503, 'TARGETS_NOT_CONFIGURED');
	}
	const entries: [string, unknown][] = Object.entries(targets);
	const allowed = new Map<string, RelayTarget>();
	for (const [id, target] of entries) {
		if (
			!/^[a-zA-Z0-9_-]{1,64}$/.test(id) ||
			target === null ||
			typeof target !== 'object' ||
			Array.isArray(target) ||
			Object.keys(target).length !== 2 ||
			!('hostname' in target) ||
			typeof target.hostname !== 'string' ||
			!/^[a-zA-Z0-9.-]{1,253}$/.test(target.hostname) ||
			!('port' in target) ||
			typeof target.port !== 'number' ||
			!Number.isInteger(target.port) ||
			target.port < 1 ||
			target.port > 65535
		) {
			return errorResponse(503, 'TARGETS_NOT_CONFIGURED');
		}
		allowed.set(id, { hostname: target.hostname, port: target.port });
	}
	const target = allowed.get(targetId);
	if (!target) {
		return errorResponse(403, 'TARGET_NOT_ALLOWED');
	}
	return target;
}
