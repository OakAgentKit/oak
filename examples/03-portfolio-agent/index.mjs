// SPDX-License-Identifier: MIT
import { pathToFileURL } from 'node:url';
import { formatAmount } from '@oakagentkit/core/amounts';
import { openExample, readTool } from '../shared/client.mjs';
export async function portfolio(client) {
  const [balanceStatus, positionStatus] = await Promise.all([
    readTool(client, 'balances'), readTool(client, 'positions'),
  ]);
  const balances = Array.isArray(balanceStatus) ? balanceStatus : balanceStatus.items;
  if (!Array.isArray(balances)) throw new Error('Oak returned unreadable balances.');
  const positions = positionStatus.positions;
  const warnings = new Set(positions.filter(item => item.id === 'error').map(item => item.description));
  for (const program of positionStatus.programs) {
    if (program.status !== 'complete') warnings.add(program.reason ?? `${program.program}: ${program.status}`);
  }
  for (const program of positionStatus.incomplete) {
    if (!positionStatus.programs.some(item => item.program === program && item.status !== 'complete')) warnings.add(`${program}: incomplete`);
  }
  for (const program of positionStatus.notIndexed) warnings.add(`${program}: not indexed`);
  return {
    balances: balances.map(item => ({ ...item, humanAmount: formatAmount(item.amount, item.token.decimals) })),
    positions, warnings: [...warnings],
    coverage: { incomplete: positionStatus.incomplete, notIndexed: positionStatus.notIndexed, programs: positionStatus.programs },
    ...(balanceStatus.summary ? { balanceSummary: balanceStatus.summary } : {}),
    ...(balanceStatus.nextStep ? { nextStep: balanceStatus.nextStep } : {}),
  };
}
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const connection = await openExample();
  try { console.log(JSON.stringify(await portfolio(connection.client), null, 2)); }
  finally { await connection.close(); }
}
