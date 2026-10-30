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
  } finally { await connection.close(); }
});
test('partial module failures remain visible, not zero balances', async () => {
  const connection = await fixtureConnection({ overrides: { positions: () => [
    { module: 'morpho', id: 'error', chainId: 4663, assets: [], description: 'morpho: unavailable' },
  ] } });
  try { assert.deepEqual((await portfolio(connection.client)).warnings, ['morpho: unavailable']); }
  finally { await connection.close(); }
});
