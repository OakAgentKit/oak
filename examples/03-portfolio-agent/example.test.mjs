// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { ECOSYSTEM_TOKENS } from '@oakagentkit/core/tokens';
import { fixtureConnection } from '../shared/fixtures.mjs';
import { portfolio } from './index.mjs';
// This fixture has no UP contract reader; 0.4.4 preserves that gap as unknown holdings.
const upUnavailable = 'UP positions could not be read; missing holdings are unknown.';
test('balances and cross-project positions use two hosted reads plus local partner balance and FOBO escrow reads', async () => {
  const calls = [], rpcCalls = [], signingCalls = [];
  const connection = await fixtureConnection({ calls, rpcCalls, signingCalls });
  try {
    const result = await portfolio(connection.client);
    assert.deepEqual(calls.map(call => call.name).sort(), ['balances', 'positions']);
    assert.equal(result.balances[0].amount, '25000000');
    assert.equal(result.balances[0].humanAmount, '25');
    assert.deepEqual(result.positions.map(item => item.module), ['steakhouse', 'morpho', 'uniswap']);
    assert.deepEqual(result.warnings, [upUnavailable]);
    assert.deepEqual(result.coverage.incomplete, ['up']);
    assert.deepEqual(result.coverage.notIndexed, []);
    assert.deepEqual(result.coverage.programs.at(-1), { program: 'fobo', status: 'complete' });
    assert.deepEqual(result.coverage.programs.find(item => item.program === 'up'),
      { program: 'up', status: 'incomplete', reason: upUnavailable });
    assert.equal(rpcCalls[0]?.name, 'getChainId');
    assert.deepEqual(rpcCalls.map(call => call.name).sort(), ['getBlock', 'getBlock', 'getChainId', 'getChainId', 'readContract', 'readContract', 'readContract']);
    const contractReads = rpcCalls.filter(call => call.name === 'readContract').map(call => call.args[0].functionName);
    assert.deepEqual([...contractReads].sort(), ['aggregate3', 'getOrder', 'orderCount']);
    // FOBO derives the getOrder IDs from orderCount; partner aggregate3 is independent.
    assert(contractReads.indexOf('orderCount') < contractReads.indexOf('getOrder'));
    const partnerRead = rpcCalls.find(call => call.args[0]?.functionName === 'aggregate3');
    assert.deepEqual(partnerRead.args[0].args[0].map(call => call.target), ECOSYSTEM_TOKENS.map(token => token.address));
    assert.deepEqual(result.balances.map(item => [item.token.symbol, item.amount, item.humanAmount]),
      [['USDG', '25000000', '25'], ['HOOKR', 'unavailable', 'unavailable']]);
    assert.deepEqual(signingCalls, []);
  } finally { await connection.close(); }
});
test('partial module failures remain visible, not zero balances', async () => {
  const connection = await fixtureConnection({ overrides: { positions: () => ({ incomplete: ['morpho'], notIndexed: [],
    programs: [{ program: 'morpho', status: 'incomplete', reason: 'morpho: unavailable' }], positions: [
    { module: 'morpho', id: 'error', chainId: 4663, assets: [], description: 'morpho: unavailable' },
  ] }) } });
  try { assert.deepEqual((await portfolio(connection.client)).warnings, ['morpho: unavailable', upUnavailable]); }
  finally { await connection.close(); }
});

test('coverage gaps without error rows remain visible', async () => {
  const connection = await fixtureConnection({ overrides: { positions: () => ({
    positions: [], incomplete: ['morpho', 'steakhouse'], notIndexed: ['uniswap'],
    programs: [{ program: 'morpho', status: 'incomplete', reason: 'morpho: reader unavailable' }],
  }) } });
  try {
    const result = await portfolio(connection.client);
    assert.deepEqual(result.positions, []);
    assert.deepEqual(result.warnings, ['morpho: reader unavailable', upUnavailable, 'steakhouse: incomplete', 'uniswap: not indexed']);
    assert.deepEqual(result.coverage.notIndexed, ['uniswap']);
  } finally { await connection.close(); }
});

test('structured balances preserve the empty-wallet summary without inventing setup state', async () => {
  const connection = await fixtureConnection({ overrides: { balances: () => [] }, rpcOverrides: {
    readContract: async args => {
      if (args.functionName === 'aggregate3') return args.args[0].map(() => ({ success: true, returnData: `0x${'0'.repeat(64)}` }));
      if (args.functionName === 'orderCount') return 0n;
      if (args.functionName === 'getOrder') return { owner: '0x1111111111111111111111111111111111111111', remaining: 0n, kind: 0 };
      throw new Error('Unexpected empty-wallet fixture read');
    },
  } });
  try {
    const result = await portfolio(connection.client);
    assert.deepEqual(result.balances, []);
    assert.equal(typeof result.balanceSummary, 'string');
    assert.equal(result.nextStep, 'Ask me to check your balance again.', 'missing rows prompt another read, not invented funding or setup state');
    assert.doesNotMatch(result.balanceSummary, /register|funded|ready to trade/i);
  } finally { await connection.close(); }
});

test('local FOBO escrow outage remains incomplete instead of being reported as zero', async () => {
  const signingCalls = [];
  const connection = await fixtureConnection({ signingCalls, rpcOverrides: {
    getBlock: async () => { throw new Error('Fixture FOBO block unavailable'); },
  } });
  try {
    const result = await portfolio(connection.client);
    assert.deepEqual(result.coverage.incomplete, ['up', 'fobo']);
    assert.equal(result.coverage.programs.at(-1).status, 'incomplete');
    assert.match(result.warnings.join('\n'), /FOBO escrow could not be read/);
    assert.deepEqual(signingCalls, []);
  } finally { await connection.close(); }
});

test('local FOBO nonzero escrow is retained separately from wallet balances', async () => {
  const connection = await fixtureConnection({ rpcOverrides: {
    readContract: async args => {
      if (args.functionName === 'orderCount') return 0n;
      if (args.functionName === 'getOrder') return {
        owner: '0x1111111111111111111111111111111111111111', remaining: 42n, kind: 0,
        payToken: `0x${'0'.repeat(40)}`,
      };
      throw new Error('Unexpected fixture read');
    },
  } });
  try {
    const result = await portfolio(connection.client);
    assert.equal(result.positions.at(-1).module, 'fobo');
    assert.equal(result.positions.at(-1).assets[0].amount, '42');
    assert.equal(result.balances[0].amount, '25000000');
    assert.deepEqual(result.coverage.incomplete, ['up']);
  } finally { await connection.close(); }
});

test('legacy array text and structured items render unavailable balances and retain exact numeric amounts', async () => {
  const item = { token: { address: '0x2222222222222222222222222222222222222222', symbol: 'USDG', decimals: 6, chainId: 4663 }, amount: '9007199254740993000001' };
  const unavailable = { token: { ...item.token, symbol: 'HOOKR', decimals: 18 }, amount: 'unavailable',
    note: 'Balance read failed; retry later.', usdEstimate: null, estimateReason: 'Balance unavailable.' };
  const zero = { ...item, amount: '0' };
  for (const structured of [false, true]) {
    const client = { callTool: async ({ name }) => {
      const data = name === 'balances' ? [item, unavailable, zero] : { positions: [], incomplete: [], notIndexed: [], programs: [] };
      return { content: [{ type: 'text', text: JSON.stringify(data) }],
        ...(structured ? { structuredContent: name === 'balances' ? { items: data, summary: 'Balance summary', nextStep: 'Ask about setup' } : data } : {}) };
    } };
    const result = await portfolio(client);
    assert.deepEqual(result.balances[0].token, item.token);
    assert.equal(result.balances[0].amount, item.amount);
    assert.equal(result.balances[0].humanAmount, '9007199254740993.000001');
    assert.deepEqual(result.balances[1], { ...unavailable, humanAmount: 'unavailable' });
    assert.equal(result.balances[2].humanAmount, '0');
    if (structured) {
      assert.equal(result.balanceSummary, 'Balance summary');
      assert.equal(result.nextStep, 'Ask about setup');
    }
  }
});
