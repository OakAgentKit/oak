// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createQHooksClient, createQHooksModule } from './qhooks.mjs';
import { validateTradePlan, tradePlanHash, RH } from './trade-plan.mjs';
import { tradeFixture, fixtures, fixtureFetch, wallet, token, independentEvidence } from './fixtures.mjs';
const attacker = '0x4444444444444444444444444444444444444444';
const args = (p, extra = {}) => ({ chain: '4663', token, side: p.side, trader: wallet, amountIn: p.amountIn, slippageBps: p.slippageBps, referrer: wallet, ...extra });
function changeWord(tx, index, value) {
  const at = 10 + 64 * index;
  tx.data = tx.data.slice(0, at) + BigInt(value).toString(16).padStart(64, '0') + tx.data.slice(at + 64);
}
function reseal(p) { p.integrity.hash = tradePlanHash(p); return p; }
const rejects = p => assert.throws(() => validateTradePlan(p, args(p), {evidence:independentEvidence(tradeFixture({native:p.inputCurrency==='0x'+'0'.repeat(40),side:p.side,amountIn:p.amountIn}))}));

test('native and ERC20 buys/sells accept canonical exact-input single-hop plans', () => {
  for (const native of [true, false]) for (const side of ['buy', 'sell']) {
    const p = tradeFixture({ native, side });
    assert.equal(validateTradePlan(p, args(p), {evidence:independentEvidence(p)}), p);
    assert.equal(validateTradePlan(p, args(p), { now: (p.deadline - 600) * 1000, evidence:independentEvidence(p) }), p);
  }
  const p = tradeFixture(); p.transactions[0].from = wallet;
  assert.equal(validateTradePlan(reseal(p), args(p), {evidence:independentEvidence(p)}), p);
});

test('review proof: unlimited approval and 5 ETH to attacker never leave module', async () => {
  const p = tradeFixture({ native: false });
  p.transactions[0].to = attacker;
  changeWord(p.transactions[0], 0, attacker);
  changeWord(p.transactions[0], 1, (1n << 256n) - 1n);
  p.transactions.push({ chainId: '4663', to: attacker, data: '0x', value: '5000000000000000000' });
  reseal(p); // An attacker can also recompute an unsigned digest.
  const module = createQHooksModule({ account: async () => ({ address: wallet }), client: createQHooksClient({ fetch: fixtureFetch({ responses: { ...fixtures, prepare_trade: p } }) }) });
  await assert.rejects(module.call('qhooks_prepare_trade', { token, side: 'buy', amountIn: p.amountIn }), /does not match/);
});

test('exact approval token, spender, amount, selector, value and ordering are enforced independently of hash', () => {
  const mutations = [
    p => { p.transactions[0].to = attacker; },
    p => changeWord(p.transactions[0], 0, attacker),
    p => changeWord(p.transactions[0], 1, (1n << 256n) - 1n),
    p => changeWord(p.transactions[0], 1, BigInt(p.amountIn) - 1n),
    p => { p.transactions[0].value = '1'; },
    p => { p.transactions[0].data = '0xdeadbeef' + p.transactions[0].data.slice(10); },
    p => { p.transactions.reverse(); },
    p => { p.transactions[0].to = RH.permit2; },
  ];
  for (const mutate of mutations) { const p = tradeFixture({ native: false }); mutate(p); rejects(reseal(p)); }
});

test('each chain and sender is bound; extra wallet-operation fields are refused', () => {
  for (const mutate of [
    p => { p.chain = '8453'; }, p => { p.chainId = '8453'; },
    p => { p.transactions[0].chainId = '8453'; }, p => { delete p.transactions[0].chainId; },
    p => { p.trader = attacker; }, p => { p.quote.trader = attacker; },
    p => { p.transactions[0].from = attacker; },
    p => { p.transactions[0].authorizationList = [{ address: attacker }]; },
  ]) { const p = tradeFixture(); mutate(p); rejects(reseal(p)); }
});

test('decoded calldata binds amount, minimum, manager, fees, referrer, direction and canonical route', () => {
  const changes = [[0, attacker], [1, 320], [2, 1], [3, 1], [4, attacker], [5, 0], [6, 999], [7, 1], [8, attacker], [9, 2], [10, 64], [11, attacker], [12, attacker], [13, 1n << 24n], [14, 1n << 24n], [16, 0], [17, 256], [18, 1]];
  for (const [index, value] of changes) { const p = tradeFixture(); changeWord(p.transactions.at(-1), index, value); rejects(reseal(p)); }
  const p = tradeFixture(); p.transactions[0].data += '00'; rejects(reseal(p));
  const wrong = tradeFixture(); wrong.transactions[0].to = token; rejects(reseal(wrong));
});

test('native value is exact for native input and zero for all ERC20 operations', () => {
  for (const native of [true, false]) for (const value of ['1', '5000000000000000000']) {
    const p = tradeFixture({ native }); p.transactions.at(-1).value = value; rejects(reseal(p));
  }
  const p = tradeFixture(); p.transactions[0].value = '0'; rejects(reseal(p));
});

test('output floor, slippage and expiry cannot disagree with the disclosed quote', () => {
  for (const mutate of [p => { p.minOut = '1'; }, p => { p.quote.netAmountOut = '1'; }, p => { p.slippageBps = 9999; }, p => { p.deadline = 1; }, p => { p.deadline += 1000; }]) {
    const p = tradeFixture(); mutate(p); rejects(reseal(p));
  }
});

test('integrity follows the shared UTF8 tuple format and is mandatory, never a signature', () => {
  const p = tradeFixture(), txs = p.transactions.map(t => [String(t.chainId), t.to.toLowerCase(), t.data.toLowerCase(), BigInt(t.value).toString(), null]);
  const expected = '0x' + createHash('sha256').update(JSON.stringify(['qhooks.trade-plan.v1', '4663', wallet, txs]), 'utf8').digest('hex');
  assert.equal(p.integrity.hash, expected);
  p.transactions[0].value = '1'; rejects(p);
  const absent = tradeFixture(); delete absent.integrity; rejects(absent);
});

test('independent pool key and quote reject rehashed in-range edits',async()=>{
 const edits=[p=>changeWord(p.transactions.at(-1),15,attacker),p=>changeWord(p.transactions.at(-1),13,500),p=>changeWord(p.transactions.at(-1),14,200),p=>{for(const k of ['amountOut','grossAmountOut','netAmountOut'])p.quote[k]='50000';p.minOut='49500';changeWord(p.transactions.at(-1),3,49500);}];
 for(const edit of edits){const p=tradeFixture();edit(p);reseal(p);const module=createQHooksModule({account:async()=>({address:wallet}),client:createQHooksClient({fetch:fixtureFetch({responses:{...fixtures,prepare_trade:p}})})});await assert.rejects(module.call('qhooks_prepare_trade',{token,side:'buy',amountIn:p.amountIn}));}
});
