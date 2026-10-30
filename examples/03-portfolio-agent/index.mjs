// SPDX-License-Identifier: MIT
import { pathToFileURL } from 'node:url';
import { formatAmount } from '@oakagentkit/core/amounts';
import { openExample, readTool } from '../shared/client.mjs';
export async function portfolio(client) {
  const [balances, positions] = await Promise.all([
    readTool(client, 'balances'), readTool(client, 'positions'),
  ]);
  return {
    balances: balances.map(item => ({ ...item, humanAmount: formatAmount(item.amount, item.token.decimals) })),
    positions, warnings: positions.filter(item => item.id === 'error').map(item => item.description),
  };
}
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const connection = await openExample();
  try { console.log(JSON.stringify(await portfolio(connection.client), null, 2)); }
  finally { await connection.close(); }
}
