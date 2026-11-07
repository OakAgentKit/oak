// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { fixtureConnection } from '../shared/fixtures.mjs';
import { portfolio } from './index.mjs';
test('balances and cross-project positions use only two read calls', async () => {
  const calls = [];
  const connection = await fixtureConnection({ calls });
  try {
    const result = await portfolio(connection.client);
    assert.deepEqual(calls.map(call => call.name).sort(), ['balances', 'positions']);
    assert.equal(result.balances[0].amount, '25000000');
    assert.equal(result.balances[0].humanAmount, '25');
    assert.deepEqual(result.positions.map(item => item.module), ['steakhouse', 'morpho', 'uniswap']);
    assert.deepEqual(result.warnings, []);
    assert.deepEqual(result.coverage.incomplete, []);
    assert.deepEqual(result.coverage.notIndexed, []);
  } finally { await connection.close(); }
});
test('partial module failures remain visible, not zero balances', async () => {
  const connection = await fixtureConnection({ overrides: { positions: () => ({ incomplete: ['morpho'], notIndexed: [],
    programs: [{ program: 'morpho', status: 'incomplete', reason: 'morpho: unavailable' }], positions: [
    { module: 'morpho', id: 'error', chainId: 4663, assets: [], description: 'morpho: unavailable' },
  ] }) } });
  try { assert.deepEqual((await portfolio(connection.client)).warnings, ['morpho: unavailable']); }
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
    assert.deepEqual(result.warnings, ['morpho: reader unavailable', 'steakhouse: incomplete', 'uniswap: not indexed']);
    assert.deepEqual(result.coverage.notIndexed, ['uniswap']);
  } finally { await connection.close(); }
});

test('structured balances preserve the empty-wallet summary without inventing setup state', async () => {
  const connection = await fixtureConnection({ overrides: { balances: () => [] } });
  try {
    const result = await portfolio(connection.client);
    assert.deepEqual(result.balances, []);
    assert.equal(typeof result.balanceSummary, 'string');
    assert.equal(result.nextStep, undefined, 'missing ETH/USDG rows leave funding state unknown');
  } finally { await connection.close(); }
});

test('legacy array text and new structured items retain token metadata and exact amounts', async () => {
  const item = { token: { address: '0x2222222222222222222222222222222222222222', symbol: 'USDG', decimals: 6, chainId: 4663 }, amount: '9007199254740993000001' };
  for (const structured of [false, true]) {
    const client = { callTool: async ({ name }) => {
      const data = name === 'balances' ? [item] : { positions: [], incomplete: [], notIndexed: [], programs: [] };
      return { content: [{ type: 'text', text: JSON.stringify(data) }],
        ...(structured ? { structuredContent: name === 'balances' ? { items: data, summary: 'Balance summary', nextStep: 'Ask about setup' } : data } : {}) };
    } };
    const result = await portfolio(client);
    assert.deepEqual(result.balances[0].token, item.token);
    assert.equal(result.balances[0].amount, item.amount);
    assert.equal(result.balances[0].humanAmount, '9007199254740993.000001');
    if (structured) {
      assert.equal(result.balanceSummary, 'Balance summary');
      assert.equal(result.nextStep, 'Ask about setup');
    }
  }
});
