// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { fixtureConnection, quoteFixture } from '../shared/fixtures.mjs';
import { previewSwap } from './index.mjs';
const show = () => {};
for (const confirmed of [false, true, 'yes']) {
  test(`preview then confirmation ${confirmed}: never invokes swap`, async () => {
    const calls = [], shown = [];
    const connection = await fixtureConnection({ calls });
    try {
      const result = await previewSwap(connection.client, {}, {
        show: text => shown.push(JSON.parse(text.startsWith('{') ? text : '{}')),
        confirm: async () => {
          assert.ok(shown.some(item => item.preview));
          return confirmed;
        },
      });
      assert.equal(result.status, confirmed === true ? 'manual-handoff' : 'stopped');
      assert.deepEqual(calls.map(call => call.name), ['find_token', 'find_token', 'quote', 'preview']);
      assert.equal(result.txs.length, 2);
      // ERC-20 approve's second ABI word is exactly the quoted input, not uint256 max.
      assert.equal(BigInt(`0x${result.txs[0].data.slice(-64)}`), 10000000n);
      assert.equal(result.quote.minAmountOut, '4975000000000000');
      assert.deepEqual(calls.at(-1).args.txs, result.txs);
    } finally { await connection.close(); }
  });
}
for (const [label, overrides, pattern] of [
  ['missing calldata', { quote: args => ({ ...quoteFixture(args), data: undefined }) }, /no prepared calldata/],
  ['expired quote', { quote: args => quoteFixture(args, 1) }, /expired/i],
  ['wrong pair', { quote: args => ({ ...quoteFixture(args), from: '0x4444444444444444444444444444444444444444' }) }, /does not match/],
  ['unverified token', { find_token: () => ({ matches: [], unverified: [], warnings: [] }) }, /unambiguous verified/],
  ['simulation failure', { preview: () => { throw new Error('Simulation failed'); } }, /unavailable|failed/i],
]) {
  test(`${label} stops before confirmation`, async () => {
    const connection = await fixtureConnection({ overrides });
    try {
      await assert.rejects(previewSwap(connection.client, {}, { show, confirm: () => assert.fail('must not confirm') }), pattern);
    } finally { await connection.close(); }
  });
}
test('amount precision and confirmation expiry fail closed', async () => {
  const connection = await fixtureConnection();
  try {
    await assert.rejects(previewSwap(connection.client, { amountIn: 10 }, { show }), /integer string/);
    let now = Math.floor(Date.now() / 1000);
    await assert.rejects(previewSwap(connection.client, {}, { show, now: () => now,
      confirm: async () => { now += 61; return true; } }), /expired while confirming/);
  } finally { await connection.close(); }
});
