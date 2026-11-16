// SPDX-License-Identifier: MIT
export const wallet = '0x1111111111111111111111111111111111111111';
export const token = '0x2222222222222222222222222222222222222222';
export const router = '0x79d211f5137d22b0fe3bfda81fbb8b7f53248bff';
import { tradePlanHash } from './trade-plan.mjs';
const zero = '0x' + '0'.repeat(40), quoteToken = '0x1000000000000000000000000000000000000000';
const word = value => BigInt(value).toString(16).padStart(64, '0');
export function tradeFixture({ native = true, side = 'buy', referrer = wallet, amountIn = '1000000000000000', slippageBps = 100, trader = wallet, approve = !native || side === 'sell' } = {}) {
  const input = side === 'sell' ? token : native ? zero : quoteToken;
  const output = side === 'buy' ? token : native ? zero : quoteToken;
  const direction = BigInt(input) < BigInt(output), amount = BigInt(amountIn);
  const gross = 100000n, net = gross - (side === 'sell' ? gross * 100n / 10000n : 0n);
  const minOut = (net * BigInt(10000 - slippageBps) / 10000n).toString(), deadline = Math.floor(Date.now() / 1000) + 600;
  const plan = { chain: '4663', chainId: '4663', token, side, trader, inputCurrency: input, amountIn, minOut, slippageBps, deadline,
    transactions: [], quote: { chainId: '4663', poolId: '0x' + 'a'.repeat(64), zeroForOne: direction, trader, source: 'V4Quoter', routerFeeBps: 100, amountIn: (amount - (side === 'buy' ? amount * 100n / 10000n : 0n)).toString(), amountOut: gross.toString(), grossAmountOut: gross.toString(), netAmountOut: net.toString() }, notes: ['Unsigned fixture; no signing or broadcasting.'] };
  if (approve) plan.transactions.push({ chainId: '4663', to: input, value: '0', data: '0x095ea7b3' + word(router) + word(amount) });
  const key = direction ? [input, output] : [output, input];
  const args = ['0x8366a39cc670b4001a1121b8f6a443a643e40951', 288, amount, minOut, zero, side === 'buy' ? 1 : 0, 100, deadline, referrer, 1, 32, ...key, 3000, 60, '0x3333333333333333333333333333333333333333', direction ? 1 : 0, 224, 0];
  plan.transactions.push({ chainId: '4663', to: router, data: '0xf5ec7c4b' + args.map(word).join(''), value: input === zero ? amountIn : '0' });
  plan.integrity = { schema: 'qhooks.trade-plan.v1', algorithm: 'sha256', hash: tradePlanHash(plan) };
  return plan;
}
export const fixtures = {
  list_launches: { markets: [], at: '2026-11-16T00:00:00Z', source: 'QHooks fixture' },
  token_info: { meta: { token, chainId: '4663', stale: true }, observedAt: '2026-11-15T00:00:00Z' },
  quote: { chainId: '4663', amountIn: '1000000000000000', amountOut: '3', observedAt: '2026-11-16T00:00:00Z', includes: 'Pool and hook charges; router fee separate.' },
  qproof_check: { version: 1, state: 'not_checked', subject: { chain: 'robinhood', address: token }, report: null },
  hooks_catalog: { snapshotAt: '2026-11-15T00:00:00Z', rows: [], coverage: 'fixture only' },
  prepare_trade: tradeFixture(),
  prepare_launch: { chain: '4663', style: 'fixed', link: 'https://qhooks.com/launch?chain=4663&name=Example&ticker=EX', notes: ['Review in browser.'] },
};
export function fixtureFetch({ calls = [], responses = fixtures } = {}) {
  return async (url, options) => {
    if (url !== 'https://qhooks.com/mcp') throw new Error('Unexpected endpoint.');
    const request = JSON.parse(options.body); calls.push({ ...request, headers: options.headers });
    if (request.method === 'notifications/initialized') return new Response(null, { status: 202 });
    const result = request.method === 'initialize' ? { protocolVersion: '2025-06-18', capabilities: { tools: {} }, serverInfo: { name: 'QHooks fixture', version: '8.0.1' } }
      : { content: [{ type: 'text', text: JSON.stringify(responses === fixtures && request.params.name === 'prepare_trade' ? tradeFixture(request.params.arguments) : responses[request.params.name]) }] };
    return Response.json({ jsonrpc: '2.0', id: request.id, result }, { headers: { 'mcp-session-id': 'offline-fixture-only' } });
  };
}
export function fixtureOak() {
  return { client: { async callTool({ name, arguments: args }) {
    if (name !== 'account' || Object.keys(args || {}).length) throw new Error('No Oak action is allowed in this example.');
    return { structuredContent: { address: wallet, chainId: 4663 }, content: [] };
  } }, close: async () => {} };
}
