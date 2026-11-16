// SPDX-License-Identifier: MIT
export const wallet = '0x1111111111111111111111111111111111111111';
export const token = '0x2222222222222222222222222222222222222222';
export const router = '0x3333333333333333333333333333333333333333';
export const fixtures = {
  list_launches: { markets: [], at: '2026-11-16T00:00:00Z', source: 'QHooks fixture' },
  token_info: { meta: { token, chainId: '4663', stale: true }, observedAt: '2026-11-15T00:00:00Z' },
  quote: { chainId: '4663', amountIn: '1000000000000000', amountOut: '3', observedAt: '2026-11-16T00:00:00Z', includes: 'Pool and hook charges; router fee separate.' },
  qproof_check: { version: 1, state: 'not_checked', subject: { chain: 'robinhood', address: token }, report: null },
  hooks_catalog: { snapshotAt: '2026-11-15T00:00:00Z', rows: [], coverage: 'fixture only' },
  prepare_trade: { chain: '4663', token, side: 'buy', trader: wallet, amountIn: '1000000000000000', minOut: '2', deadline: 2000000000,
    transactions: [{ to: router, data: '0x12345678', value: '0x38d7ea4c68000' }], quote: { routerFeeBps: 100 }, notes: ['Unsigned fixture; no signing or broadcasting.'] },
  prepare_launch: { chain: '4663', style: 'fixed', link: 'https://qhooks.com/launch?chain=4663&name=Example&ticker=EX', notes: ['Review in browser.'] },
};
export function fixtureFetch({ calls = [], responses = fixtures } = {}) {
  return async (url, options) => {
    if (url !== 'https://qhooks.com/mcp') throw new Error('Unexpected endpoint.');
    const request = JSON.parse(options.body); calls.push({ ...request, headers: options.headers });
    if (request.method === 'notifications/initialized') return new Response(null, { status: 202 });
    const result = request.method === 'initialize' ? { protocolVersion: '2025-06-18', capabilities: { tools: {} }, serverInfo: { name: 'QHooks fixture', version: '8.0.1' } }
      : { content: [{ type: 'text', text: JSON.stringify(responses[request.params.name]) }] };
    return Response.json({ jsonrpc: '2.0', id: request.id, result }, { headers: { 'mcp-session-id': 'offline-fixture-only' } });
  };
}
export function fixtureOak() {
  return { client: { async callTool({ name, arguments: args }) {
    if (name !== 'account' || Object.keys(args || {}).length) throw new Error('No Oak action is allowed in this example.');
    return { structuredContent: { address: wallet, chainId: 4663 }, content: [] };
  } }, close: async () => {} };
}
