// SPDX-License-Identifier: MIT
import { pathToFileURL } from 'node:url';
import { createInterface } from 'node:readline/promises';
import { baseUnits } from '@oakagentkit/core/amounts';
import { normalizeQuote, buildSwapFromQuote } from '@oakagentkit/core/swap';
import { openExample, readTool, prepareAction, executeAction } from '../shared/client.mjs';

export async function previewSwap(client, { from = 'USDG', to = 'WETH', amountIn = '10000000', slippageBps = 50 } = {},
  { show = console.log, confirm = async () => false, now = () => Math.floor(Date.now() / 1000) } = {}) {
  if (baseUnits(amountIn) <= 0n) throw new Error('amountIn must be a positive base-unit string.');
  if (!Number.isInteger(slippageBps) || slippageBps < 0 || slippageBps >= 10000) throw new Error('Invalid slippageBps.');
  async function token(query) {
    const result = await readTool(client, 'find_token', { query });
    show(JSON.stringify(result, null, 2));
    const matches = result.matches.filter(item => item.verified === true);
    if (matches.length !== 1) throw new Error('Choose an unambiguous verified token address.');
    return matches[0];
  }
  const input = await token(from);
  const output = await token(to);
  const raw = await readTool(client, 'quote', { from: input.address, to: output.address, amountIn, slippageBps });
  show(JSON.stringify({ quote: raw }, null, 2));
  // Fail closed on incomplete route data; never invent calldata.
  if (!raw.data) throw new Error('Quote has no prepared calldata; request a complete route.');
  const same = (a, b) => typeof a === 'string' && a.toLowerCase() === b.toLowerCase();
  if (!same(raw.from, input.address) || !same(raw.to, output.address) || raw.amountIn !== amountIn ||
      raw.chainId !== 4663 || raw.slippageBps !== slippageBps) throw new Error('Quote does not match the request.');
  const quote = normalizeQuote(raw, { now });
  const txs = buildSwapFromQuote(quote, { now });
  const prepared = await prepareAction(client, 'swap', { quoteId: quote.quoteId });
  if (typeof prepared.summary !== 'string' || !prepared.summary.trim() ||
      !/^oa_[0-9a-f]{40}_[0-9a-f]{32}_[0-9a-f]{64}$/.test(prepared.actionId) ||
      !Number.isSafeInteger(prepared.expiresAt)) throw new Error('Oak returned an invalid prepared action.');
  const expired = () => now() >= prepared.expiresAt || BigInt(now()) >= BigInt(quote.expiresAt);
  if (expired()) throw new Error('Action or quote expired; prepare a fresh summary.');
  await show(prepared.summary);
  await show(`Action: ${prepared.actionId}\nExpires: ${new Date(prepared.expiresAt * 1000).toISOString()}`);
  // The callback represents the person's answer after reading this exact summary.
  const confirmed = await confirm(prepared);
  if (confirmed !== true) return { status: 'stopped', quote, txs, prepared };
  if (expired()) throw new Error('Action or quote expired while confirming; prepare a fresh summary.');
  const execution = await executeAction(client, prepared.actionId);
  await show(execution.summary);
  return { status: execution.status, quote, txs, prepared, execution };
}
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const connection = await openExample();
  try {
    const result = await previewSwap(connection.client, {
      from: process.env.OAK_FROM || 'USDG', to: process.env.OAK_TO || 'WETH',
      amountIn: process.env.OAK_AMOUNT_IN || '10000000', slippageBps: Number(process.env.OAK_SLIPPAGE_BPS || '50'),
    }, { confirm: async () => {
      if (!process.stdin.isTTY || !process.stdout.isTTY) return false;
      const prompt = createInterface({ input: process.stdin, output: process.stdout });
      try { return (await prompt.question('Execute this action? Type yes or no: ')).trim().toLowerCase() === 'yes'; }
      catch { return false; }
      finally { prompt.close(); }
    } });
    console.log(result.status);
  } finally { await connection.close(); }
}
