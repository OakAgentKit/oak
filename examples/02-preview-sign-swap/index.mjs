// SPDX-License-Identifier: MIT
import { pathToFileURL } from 'node:url';
import { createInterface } from 'node:readline/promises';
import { baseUnits } from '@oakagentkit/core/amounts';
import { normalizeQuote, buildSwapFromQuote } from '@oakagentkit/core/swap';
import { openExample, readTool } from '../shared/client.mjs';

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
  // Never invent calldata or call the action tool to obtain it.
  if (!raw.data) throw new Error('Quote has no prepared calldata; cannot preview this route without an action.');
  const same = (a, b) => typeof a === 'string' && a.toLowerCase() === b.toLowerCase();
  if (!same(raw.from, input.address) || !same(raw.to, output.address) || raw.amountIn !== amountIn ||
      raw.chainId !== 4663 || raw.slippageBps !== slippageBps) throw new Error('Quote does not match the request.');
  const quote = normalizeQuote(raw, { now });
  const txs = buildSwapFromQuote(quote, { now });
  const preview = await readTool(client, 'preview', { txs });
  show(JSON.stringify({ txs, preview }, null, 2));
  if (BigInt(quote.expiresAt) <= BigInt(now())) throw new Error('Quote expired; request a fresh quote and preview.');
  const confirmed = await confirm();
  if (confirmed !== true) return { status: 'stopped', quote, txs, preview };
  if (BigInt(quote.expiresAt) <= BigInt(now())) throw new Error('Quote expired while confirming; request a fresh preview.');
  show('Confirmed for manual handoff only. No transaction was signed or sent. Request a fresh quote and preview in your wallet client before approving its swap action.');
  return { status: 'manual-handoff', quote, txs, preview };
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
      try { return await prompt.question('Review complete? Type CONFIRM for manual handoff (no signing): ') === 'CONFIRM'; }
      catch { return false; }
      finally { prompt.close(); }
    } });
    console.log(result.status);
  } finally { await connection.close(); }
}
