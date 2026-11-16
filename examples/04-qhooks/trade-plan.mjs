// SPDX-License-Identifier: MIT
import { createHash } from 'node:crypto';

// This example supports only prepare_trade's current RH single-hop QFeeRouter
// ABI. A new route/selector needs an explicit local validator, not a wider allowlist.
export const RH = Object.freeze({
  chainId: '4663',
  feeRouter: '0x79d211f5137d22b0fe3bfda81fbb8b7f53248bff',
  permit2: '0x000000000022d473030f116ddee9f6b43ac78ba3',
  manager: '0x8366a39cc670b4001a1121b8f6a443a643e40951',
});
const ZERO = '0x' + '0'.repeat(40);
const ADDRESS = /^0x[0-9a-f]{40}$/i, HEX = /^0x(?:[0-9a-f]{2})*$/i;
const UINT = /^(0|[1-9][0-9]*)$/, U128 = 1n << 128n;
const fail = () => { throw new Error('QHooks unsigned plan does not match the request.'); };
const addr = value => typeof value === 'string' && ADDRESS.test(value) ? value.toLowerCase() : fail();
function uint(value, limit = 1n << 256n) {
  if (typeof value !== 'string' || !UINT.test(value) || value.length > 78) fail();
  const n = BigInt(value); if (n >= limit) fail(); return n;
}
function valueOf(value) {
  if (typeof value !== 'string' || !/^(?:0x[0-9a-f]+|0|[1-9][0-9]*)$/i.test(value) || value.length > 78) fail();
  const n = BigInt(value); if (n >= 1n << 256n) fail(); return n;
}
function words(data, selector, count) {
  if (typeof data !== 'string' || !HEX.test(data) || data.slice(0, 10).toLowerCase() !== selector || data.length !== 10 + count * 64) fail();
  return Array.from({ length: count }, (_, i) => data.slice(10 + i * 64, 74 + i * 64).toLowerCase());
}
const wordAddress = word => /^0{24}[0-9a-f]{40}$/.test(word) ? '0x' + word.slice(24) : fail();
const number = word => BigInt('0x' + word);
function signed24(word) {
  let n = number(word); if (n >= 1n << 255n) n -= 1n << 256n;
  if (n < -(1n << 23n) || n >= 1n << 23n) fail(); return n;
}

// Shared server format. A digest detects accidental modification; it is NOT a
// server signature or a substitute for the independent request/ABI checks below.
export function tradePlanHash(plan) {
  const tuple = ['qhooks.trade-plan.v1', String(plan.chainId), addr(plan.trader),
    plan.transactions.map(tx => [String(tx.chainId), addr(tx.to), tx.data.toLowerCase(), valueOf(tx.value).toString(), tx.from === undefined ? null : addr(tx.from)])];
  return '0x' + createHash('sha256').update(JSON.stringify(tuple), 'utf8').digest('hex');
}

export function validateTradePlan(plan, input, { now = Date.now() } = {}) {
  const chain = input.chain ?? RH.chainId, trader = addr(input.trader), token = addr(input.token);
  const amount = uint(input.amountIn, U128), slippage = input.slippageBps ?? 100;
  if (chain !== RH.chainId || amount === 0n || !['buy', 'sell'].includes(input.side) || !Number.isInteger(slippage) || slippage < 0 || slippage > 9999) fail();
  if (!plan || String(plan.chainId) !== chain || String(plan.chain) !== chain || addr(plan.trader) !== trader || addr(plan.token) !== token || plan.side !== input.side || plan.amountIn !== input.amountIn || plan.slippageBps !== slippage) fail();
  const minimum = uint(plan.minOut, U128), inputCurrency = addr(plan.inputCurrency), feeOnInput = input.side === 'buy';
  const q = plan.quote;
  if (!q || String(q.chainId) !== chain || addr(q.trader) !== trader || typeof q.zeroForOne !== 'boolean' || q.routerFeeBps !== 100 || q.source !== 'V4Quoter') fail();
  const gross = uint(q.grossAmountOut, U128), net = uint(q.netAmountOut, U128);
  if (minimum === 0n || gross === 0n || net !== gross - (feeOnInput ? 0n : gross * 100n / 10000n) || minimum !== net * BigInt(10000 - slippage) / 10000n || uint(q.amountOut, U128) !== gross || uint(q.amountIn, U128) !== amount - (feeOnInput ? amount * 100n / 10000n : 0n)) fail();
  if (!Number.isSafeInteger(plan.deadline) || !Number.isFinite(now) || plan.deadline <= Math.floor(now / 1000) || plan.deadline > Math.floor(now / 1000) + 660) fail();
  const txs = plan.transactions;
  if (!Array.isArray(txs) || txs.length < 1 || txs.length > 2) fail();
  const allowed = new Set([inputCurrency, RH.feeRouter, RH.permit2]);
  for (const tx of txs) {
    if (!tx || Object.keys(tx).some(k => !['chainId', 'to', 'data', 'value', 'from'].includes(k)) || String(tx.chainId) !== chain || !allowed.has(addr(tx.to)) || tx.from !== undefined && addr(tx.from) !== trader || typeof tx.data !== 'string' || !HEX.test(tx.data)) fail();
    valueOf(tx.value);
  }
  if (txs.length === 2) {
    const approve = txs[0], w = words(approve.data, '0x095ea7b3', 2);
    if (inputCurrency === ZERO || addr(approve.to) !== inputCurrency || wordAddress(w[0]) !== RH.feeRouter || number(w[1]) !== amount || valueOf(approve.value) !== 0n) fail();
  }
  const swap = txs.at(-1), w = words(swap.data, '0xf5ec7c4b', 19);
  // Fixed canonical layout: nine top-level words, one dynamic hop, empty hookData.
  if (addr(swap.to) !== RH.feeRouter || wordAddress(w[0]) !== RH.manager || number(w[1]) !== 288n || number(w[2]) !== amount || number(w[3]) !== minimum || wordAddress(w[4]) !== ZERO || number(w[5]) !== (feeOnInput ? 1n : 0n) || number(w[6]) !== 100n || number(w[7]) !== BigInt(plan.deadline) || wordAddress(w[8]) !== addr(input.referrer ?? ZERO) || number(w[9]) !== 1n || number(w[10]) !== 32n || number(w[13]) >= 1n << 24n || signed24(w[14]) <= 0n || number(w[16]) !== (q.zeroForOne ? 1n : 0n) || number(w[17]) !== 224n || number(w[18]) !== 0n) fail();
  const currency0 = wordAddress(w[11]), currency1 = wordAddress(w[12]); wordAddress(w[15]);
  const [currencyIn, currencyOut] = q.zeroForOne ? [currency0, currency1] : [currency1, currency0];
  if (BigInt(currency0) >= BigInt(currency1) || currencyIn !== inputCurrency || (feeOnInput ? currencyOut !== token : currencyIn !== token) || valueOf(swap.value) !== (inputCurrency === ZERO ? amount : 0n)) fail();
  // swap() returns output to msg.sender; it has no trader/recipient calldata field.
  // plan.trader, quote.trader and any tx.from are bound to the actual Oak account.
  if (plan.integrity?.schema !== 'qhooks.trade-plan.v1' || plan.integrity.algorithm !== 'sha256' || !/^0x[0-9a-f]{64}$/.test(plan.integrity.hash || '') || tradePlanHash(plan) !== plan.integrity.hash) fail();
  return plan;
}
