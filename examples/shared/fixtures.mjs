// SPDX-License-Identifier: MIT
import { ADDRESSES, ROUTE_EXECUTORS } from '@oakagentkit/core/addresses';
import { encodeKyberSwapData } from '@oakagentkit/core/swap';
import { connect, disabled, publicAddress } from './client.mjs';

export const usdg = { address: '0x2222222222222222222222222222222222222222', symbol: 'USDG', decimals: 6, chainId: 4663 };
export const weth = { address: '0x3333333333333333333333333333333333333333', symbol: 'WETH', decimals: 18, chainId: 4663 };
export const balances = [{ token: usdg, amount: '25000000' }];
export const positions = ['steakhouse', 'morpho', 'uniswap'].map((module, index) => ({
  module, id: String(index + 1), chainId: 4663, assets: [{ token: usdg, amount: '1000000' }], description: `${module} fixture`,
}));
export function quoteFixture(args = {}, now = Math.floor(Date.now() / 1000)) {
  const amountIn = args.amountIn ?? '10000000';
  const quote = {
    quoteId: `fixture-${now}-${amountIn}`, from: usdg.address, to: weth.address, wallet: publicAddress,
    chainId: 4663, provider: 'kyberswap', amountIn, amountOut: '5000000000000000',
    minAmountOut: '4975000000000000', slippageBps: 50, expiresAt: String(now + 60),
    router: ADDRESSES[4663].routes.kyberswap.address, allowance: '0', value: '0',
    input: { token: usdg, amount: amountIn, humanAmount: '10' },
    output: { token: weth, amount: '5000000000000000', humanAmount: '0.005' },
    minimumOutput: { token: weth, amount: '4975000000000000', humanAmount: '0.004975' },
  };
  quote.data = encodeKyberSwapData({ ...quote, callTarget: ROUTE_EXECUTORS[4663].kyberswap.address });
  return quote;
}
export const previewFixture = {
  chainId: 4663, blockNumber: '123', summary: 'Fixture: spend 10 USDG; receive 0.005 WETH; excludes gas.',
  changes: [{ token: usdg, amount: '-10000000' }, { token: weth, amount: '5000000000000000' }],
};
export async function fixtureConnection({ overrides = {}, calls = [] } = {}) {
  const handlers = {
    find_token: args => ({ matches: [{ ...(args.query === 'USDG' ? usdg : weth), verified: true }], unverified: [], warnings: [] }),
    quote: args => quoteFixture(args), preview: args => ({ ...previewFixture, txs: args.txs }),
    balances: () => balances, positions: () => positions, ...overrides,
  };
  return connect({
    identity: { requireVerified: async () => disabled(), unlink: disabled, sessions: { headers: async () => ({}), clear() {} } },
    fetch: async (url, options) => {
      const name = new URL(url).pathname.split('/').at(-1);
      const args = JSON.parse(options.body);
      calls.push({ name, args });
      if (!handlers[name]) throw new Error(`Unexpected fixture tool: ${name}`);
      const data = await handlers[name](args);
      return new Response(JSON.stringify({ ok: true, data }), { status: 200 });
    },
  });
}
