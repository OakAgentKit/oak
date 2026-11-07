// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { assertSwapTransaction, decodeSwapMinAmountOut } from '@oakagentkit/core/swap';
import { fixtureConnection, quoteFixture, usdg, weth } from '../shared/fixtures.mjs';
import { previewSwap } from './index.mjs';
import { executeAction } from '../shared/client.mjs';
const show = () => {};
for (const provider of ['kyberswap', 'velora']) {
for (const confirmed of [false, true, 'yes', undefined]) {
  test(`${provider} prepare, read summary, answer ${confirmed}: execute only after an explicit yes`, async () => {
    const calls = [], shown = [], toolCalls = [], senderCalls = [], signingCalls = [];
    const connection = await fixtureConnection({ calls, toolCalls, senderCalls, signingCalls,
      overrides: { quote: args => quoteFixture({ ...args, provider }) } });
    try {
      const result = await previewSwap(connection.client, {}, {
        show: async text => { await Promise.resolve(); shown.push(text); },
        confirm: async prepared => {
          assert.ok(shown.includes(prepared.summary), 'the exact plain summary was displayed before asking');
          for (const field of ['Leaves wallet:', 'Comes back:', 'Fees:', 'Token approval:', 'Warnings:']) assert.match(prepared.summary, new RegExp(field));
          assert.ok(shown.some(text => text.includes(new Date(prepared.expiresAt * 1000).toISOString())));
          assert.deepEqual(senderCalls.map(call => call.name), ['prepareAction']);
          assert.deepEqual(signingCalls, []);
          assert.ok(toolCalls.every(call => call.name !== 'oak_execute'));
          return confirmed;
        },
      });
      assert.equal(result.status, confirmed === true ? 'not_submitted' : 'stopped');
      assert.deepEqual(calls.map(call => call.name), ['find_token', 'find_token', 'quote', 'swap', 'preview']);
      assert.deepEqual(toolCalls.map(call => call.name), ['find_token', 'find_token', 'quote', 'oak_prepare', ...(confirmed === true ? ['oak_execute'] : [])]);
      assert.deepEqual(toolCalls[3].arguments, { name: 'swap', arguments: { quoteId: result.quote.quoteId } });
      assert.deepEqual(senderCalls.map(call => call.name), ['prepareAction', ...(confirmed === true ? ['executeAction'] : [])]);
      assert.deepEqual(signingCalls, [], 'fixture never signs or broadcasts, including after yes');
      if (confirmed === true) {
        assert.deepEqual(toolCalls.at(-1).arguments, { actionId: result.prepared.actionId });
        assert.deepEqual(result.execution.hashes, []);
        assert.match(result.execution.summary, /nothing was signed or sent/);
        await assert.rejects(executeAction(connection.client, result.prepared.actionId), /already used/);
      }
      assert.equal(result.txs.length, 2);
      // ERC-20 approve's second ABI word is exactly the quoted input, not uint256 max.
      assert.equal(BigInt(`0x${result.txs[0].data.slice(-64)}`), 10000000n);
      assert.equal(result.quote.minAmountOut, provider === 'kyberswap' ? '4975000000000000' : '4962562499999999');
      assert.deepEqual(calls.at(-1).args.txs, result.txs);
    } finally { await connection.close(); }
  });
}
for (const [label, overrides, pattern] of [
  ['missing calldata', { quote: args => ({ ...quoteFixture({ ...args, provider }), data: undefined }) }, /no prepared calldata/],
  ['expired quote', { quote: args => quoteFixture({ ...args, provider }, 1) }, /expired/i],
  ['wrong pair', { quote: args => ({ ...quoteFixture({ ...args, provider }), from: '0x4444444444444444444444444444444444444444' }) }, /does not match/],
  ['unverified token', { find_token: () => ({ matches: [], unverified: [], warnings: [] }) }, /unambiguous verified/],
  ['simulation failure', { preview: () => { throw new Error('Simulation failed'); } }, /unavailable|failed/i],
]) {
  test(`${provider} ${label} stops before confirmation`, async () => {
    const calls = [], toolCalls = [], senderCalls = [], signingCalls = [];
    const connection = await fixtureConnection({ calls, toolCalls, senderCalls, signingCalls, overrides: {
      quote: args => quoteFixture({ ...args, provider }), ...overrides,
    } });
    try {
      await assert.rejects(previewSwap(connection.client, {}, { show, confirm: () => assert.fail('must not confirm') }), pattern);
      assert.ok(calls.every(call => ['find_token', 'quote', 'swap', 'preview'].includes(call.name)));
      assert.ok(toolCalls.every(call => call.name !== 'oak_execute'));
      assert.deepEqual(senderCalls, [], 'invalid routes and failed simulations never reach the sender');
      assert.deepEqual(signingCalls, []);
    } finally { await connection.close(); }
  });
}
test(`${provider} fee-on quote and built calldata bind the pinned treasury`, async () => {
  const calls = [], responses = [], senderCalls = [];
  const connection = await fixtureConnection({ calls, responses, senderCalls, overrides: { quote: args => quoteFixture({ ...args, provider }) } });
  try {
    const { quote, txs } = await previewSwap(connection.client, {}, { show });
    const prepared = senderCalls.find(call => call.name === 'prepareAction');
    assert.deepEqual(prepared.txs, txs, 'locally checked builder matches the displayed quote');
    const tx = txs.at(-1);
    assert.equal(quote.oakFeeBps, 25);
    assert.equal(quote.oakFee, provider === 'kyberswap' ? '25000' : '12500000000000');
    assert.equal(quote.oakFeeToken, provider === 'kyberswap' ? usdg.address : weth.address);
    assert.equal(quote.grossAmountOut, '5000000000000000');
    assert.equal(quote.amountOut, provider === 'kyberswap' ? '5000000000000000' : '4987499999999999');
    assert.equal(quote.output.amount, quote.amountOut);
    assert.equal(responses.find(reply => reply.name === 'preview').data.changes[1].amount, quote.amountOut);
    assert.deepEqual(calls.find(call => call.name === 'preview').args.txs, txs);
    assert.equal(quote.minimumOutput.amount, quote.minAmountOut);
    assert.equal(quote.venueFee, provider === 'kyberswap' ? '0' : '1');
    assert.match(quote.feeDisclosure, /Oak fee 0\.25%/);
    assert.match(tx.description, /Oak fee 0\.25%/);
    assert.equal(decodeSwapMinAmountOut(tx.data).toString(),
      provider === 'kyberswap' ? quote.minAmountOut : '4974999999999999');
    assert.doesNotThrow(() => assertSwapTransaction(tx, quote));
    for (const changed of [{ oakFeeBps: 0 }, { oakFee: '0' }, { oakFeeToken: '0x4444444444444444444444444444444444444444' }]) {
      assert.throws(() => assertSwapTransaction(tx, { ...quote, ...changed }), /pinned rate, token and amount/);
    }
    const treasury = '856bb126188bdb5e425d3ac9d59e9ffbd12e6ecf';
    assert.ok(tx.data.toLowerCase().includes(treasury));
    const data = tx.data.toLowerCase().replace(treasury, '4444444444444444444444444444444444444444');
    assert.throws(() => assertSwapTransaction({ ...tx, data }, quote), /pinned Oak/);
  } finally { await connection.close(); }
});
}
test('amount precision and confirmation expiry fail closed', async () => {
  let now = Math.floor(Date.now() / 1000);
  const toolCalls = [], senderCalls = [];
  const connection = await fixtureConnection({ now: () => now, toolCalls, senderCalls });
  try {
    await assert.rejects(previewSwap(connection.client, { amountIn: 10 }, { show }), /integer string/);
    await assert.rejects(previewSwap(connection.client, {}, { show, now: () => now,
      confirm: async prepared => { now = prepared.expiresAt; return true; } }), /expired while confirming/);
    assert.ok(toolCalls.every(call => call.name !== 'oak_execute'));
    assert.deepEqual(senderCalls.map(call => call.name), ['prepareAction']);
  } finally { await connection.close(); }
});

test('invalid prepared actions stop before asking or executing', async () => {
  for (const changed of [{ actionId: '' }, { summary: '' }, { expiresAt: '9999999999' }, { expiresAt: 1 }]) {
    const connection = await fixtureConnection();
    const callTool = connection.client.callTool.bind(connection.client);
    connection.client.callTool = async request => {
      assert.notEqual(request.name, 'oak_execute');
      const result = await callTool(request);
      if (request.name !== 'oak_prepare') return result;
      return { ...result, structuredContent: { ...result.structuredContent, ...changed } };
    };
    try {
      await assert.rejects(previewSwap(connection.client, {}, { show,
        confirm: () => assert.fail('must not ask about an invalid action') }), /invalid prepared action|expired/);
    } finally { await connection.close(); }
  }
});

test('execute errors propagate without retrying or preparing new terms', async () => {
  const connection = await fixtureConnection();
  const callTool = connection.client.callTool.bind(connection.client);
  let executions = 0;
  connection.client.callTool = async request => {
    if (request.name !== 'oak_execute') return callTool(request);
    executions++;
    return { isError: true, content: [{ type: 'text', text: 'Fresh simulation failed. Nothing was signed.' }] };
  };
  try {
    await assert.rejects(previewSwap(connection.client, {}, { show, confirm: async () => true }), /Fresh simulation failed/);
    assert.equal(executions, 1);
  } finally { await connection.close(); }
});
