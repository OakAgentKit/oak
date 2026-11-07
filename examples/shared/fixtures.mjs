// SPDX-License-Identifier: MIT
import { ADDRESSES, ROUTE_EXECUTORS } from '@oakagentkit/core/addresses';
import { formatAmount } from '@oakagentkit/core/amounts';
import { OAK_SWAP_FEE, oakSwapFeeAmount } from '@oakagentkit/core/oak-fee';
import { buildSwapFromQuote, normalizeQuote, computeMinAmountOut, encodeKyberSwapData, encodeVeloraSwapData, formatVenueFeeDisclosure, veloraCalldataMinimum } from '@oakagentkit/core/swap';
import { connect, disabled, publicAddress } from './client.mjs';

export const usdg = { address: '0x2222222222222222222222222222222222222222', symbol: 'USDG', decimals: 6, chainId: 4663 };
export const weth = { address: '0x3333333333333333333333333333333333333333', symbol: 'WETH', decimals: 18, chainId: 4663 };
export const balances = [{ token: usdg, amount: '25000000' }];
export const positions = ['steakhouse', 'morpho', 'uniswap'].map((module, index) => ({
  module, id: String(index + 1), chainId: 4663, assets: [{ token: usdg, amount: '1000000' }], description: `${module} fixture`,
}));
export function quoteFixture(args = {}, now = Math.floor(Date.now() / 1000)) {
  const amountIn = args.amountIn ?? '10000000';
  const provider = args.provider ?? 'kyberswap';
  if (!['kyberswap', 'velora'].includes(provider)) throw new Error('Unsupported fixture provider.');
  const velora = provider === 'velora';
  const grossAmountOut = '5000000000000000';
  const oakFee = oakSwapFeeAmount(velora ? grossAmountOut : amountIn);
  // Kyber's output already includes its input fee. Velora deducts an output fee and one unit of dust.
  const amountOut = velora ? (BigInt(grossAmountOut) - BigInt(oakFee) - 1n).toString() : grossAmountOut;
  const slippageBps = args.slippageBps ?? 50;
  const minAmountOut = computeMinAmountOut(amountOut, slippageBps);
  const feeTerms = { provider, venueFee: velora ? '1' : '0', venueFeeBps: 0,
    oakFeeBps: OAK_SWAP_FEE.bps, oakFee, oakFeeToken: velora ? weth.address : usdg.address };
  const quote = {
    quoteId: `fixture-${provider}-${now}-${amountIn}-${slippageBps}`, from: usdg.address, to: weth.address, wallet: publicAddress,
    chainId: 4663, ...feeTerms, amountIn, amountOut, grossAmountOut,
    destAmountAfterFee: amountOut, netAmountOut: amountOut,
    minAmountOut, slippageBps, expiresAt: String(now + 60),
    ...(velora ? { calldataMinAmountOut: veloraCalldataMinimum(minAmountOut).toString(),
      fee: { token: weth, amount: (BigInt(grossAmountOut) - BigInt(amountOut)).toString() } } : {}),
    feeDisclosure: formatVenueFeeDisclosure(feeTerms),
    amountUnits: { amountIn: 'input token base units', amountOut: 'output token base units',
      minAmountOut: 'output token base units', humanAmount: 'decimal token units' },
    router: ADDRESSES[4663].routes[provider].address, spender: ADDRESSES[4663].routes[provider].address,
    allowance: '0', value: '0',
    input: { token: usdg, amount: amountIn, humanAmount: formatAmount(amountIn, usdg.decimals) },
    output: { token: weth, amount: amountOut, humanAmount: formatAmount(amountOut, weth.decimals) },
    minimumOutput: { token: weth, amount: minAmountOut, humanAmount: formatAmount(minAmountOut, weth.decimals) },
  };
  quote.data = velora
    ? encodeVeloraSwapData({ ...quote, amountOut: grossAmountOut, minAmountOut: quote.calldataMinAmountOut })
    : encodeKyberSwapData({ ...quote, callTarget: ROUTE_EXECUTORS[4663].kyberswap.address });
  return quote;
}
export const previewFixture = {
  chainId: 4663, blockNumber: '123', summary: 'Fixture: spend 10 USDG; receive 0.005 WETH; excludes gas.',
  changes: [{ token: usdg, amount: '-10000000' }, { token: weth, amount: '5000000000000000' }],
};
export async function fixtureConnection({ overrides = {}, calls = [], responses = [], toolCalls = [], senderCalls = [], signingCalls = [],
  now = () => Math.floor(Date.now() / 1000) } = {}) {
  let quoted;
  let simulated;
  let sequence = 0;
  const pending = new Map();
  const signingTrap = name => () => { signingCalls.push(name); disabled(); };
  const handlers = {
    find_token: args => ({ matches: [{ ...(args.query === 'USDG' ? usdg : weth), verified: true }], unverified: [], warnings: [] }),
    quote: args => quoteFixture(args, now()), preview: args => ({ ...previewFixture,
      ...(quoted ? {
        summary: `Fixture: spend ${quoted.input.humanAmount} USDG; receive ${quoted.output.humanAmount} WETH; excludes gas.`,
        changes: [{ token: usdg, amount: `-${quoted.amountIn}` }, { token: weth, amount: quoted.amountOut }],
      } : {}), txs: args.txs }),
    swap: args => {
      if (!quoted || args.quoteId !== quoted.quoteId) throw new Error('Unknown fixture quote.');
      const quote = normalizeQuote(quoted, { now });
      return { txs: buildSwapFromQuote(quote, { now }), quote, summary: 'Fixture swap; no signing or broadcast.' };
    },
    balances: () => balances, positions: () => ({ positions, incomplete: [], notIndexed: [],
      programs: positions.map(({ module }) => ({ program: module, status: 'complete' })) }), ...overrides,
  };
  const connection = await connect({
    signer: { address: publicAddress, signMessage: signingTrap('signMessage'),
      signTransaction: signingTrap('signTransaction'), signTypedData: signingTrap('signTypedData') },
    // Verified only inside this synthetic bridge; no identity or wallet is loaded.
    identity: { requireVerified: async () => {}, unlink: disabled, sessions: { headers: async () => ({}), clear() {} } },
    sender: {
      send: signingTrap('send'), signTypedData: signingTrap('sender.signTypedData'), signMessage: signingTrap('sender.signMessage'),
      blockNumber: async () => 123n,
      prepareAction: async (txs, action) => {
        senderCalls.push({ name: 'prepareAction', txs, action });
        if (!simulated) throw new Error('Fixture action requires a successful simulation.');
        const expiresAt = Math.min(now() + 300, Number(quoted.expiresAt));
        const actionId = `oa_${publicAddress.slice(2)}_${(++sequence).toString(16).padStart(32, '0')}_${'0'.repeat(64)}`;
        const summary = [
          'Fixture only: prepare swap USDG to WETH on chain 4663.',
          `Leaves wallet: ${quoted.input.humanAmount} USDG (${quoted.amountIn} base units).`,
          `Comes back: at least ${quoted.minimumOutput.humanAmount} WETH (${quoted.minAmountOut} base units).`,
          `Fees: ${quoted.feeDisclosure}; network fee unavailable in this fixture.`,
          `Token approval: exactly ${quoted.amountIn} USDG base units to ${quoted.spender}.`,
          'Warnings: illustrative simulation excludes gas and does not prove sellability or settlement.',
        ].join('\n');
        const prepared = { actionId, expiresAt, summary };
        pending.set(actionId, prepared);
        return prepared;
      },
      // This models the call boundary only, not the production sender's signing guards.
      executeAction: async actionId => {
        senderCalls.push({ name: 'executeAction', actionId });
        const prepared = pending.get(actionId);
        if (!prepared) throw new Error('Unknown or already used fixture action. Nothing was signed.');
        pending.delete(actionId);
        if (now() >= prepared.expiresAt) throw new Error('Fixture action expired. Nothing was signed.');
        return { hashes: [], status: 'not_submitted', summary: 'Fixture execution requested after yes; nothing was signed or sent.' };
      },
    },
    fixtureOptions: {
      now, wormhole: { payerMode: 'off' }, wormholeFetch: async () => Response.json({}),
      moduleClientFor: () => { throw new Error('Unexpected fixture RPC.'); },
      balanceJournal: { receivedTokens: async () => [] },
      autoDailyBudget: { status: async () => ({ capAnswered: 'skipped', capUsd: null }) },
      receiptLog: { decision: async () => {} },
    },
    fetch: async (url, options) => {
      const name = new URL(url).pathname.split('/').at(-1);
      const args = JSON.parse(options.body);
      calls.push({ name, args });
      if (!handlers[name]) throw new Error(`Unexpected fixture tool: ${name}`);
      const data = await handlers[name](args);
      responses.push({ name, data: structuredClone(data) });
      if (name === 'quote') quoted = data;
      if (name === 'preview') simulated = data;
      return new Response(JSON.stringify({ ok: true, data }), { status: 200 });
    },
  });
  const callTool = connection.client.callTool.bind(connection.client);
  connection.client.callTool = async (...args) => {
    toolCalls.push(structuredClone(args[0]));
    return callTool(...args);
  };
  return connection;
}
