// SPDX-License-Identifier: MIT
import { pathToFileURL } from 'node:url';
import { createQHooksClient, createQHooksModule } from './qhooks.mjs';
import { fixtureFetch, fixtureOak, token } from './fixtures.mjs';
export async function qhooksExample(oakClient, { fetch = fixtureFetch(), show = console.log } = {}) {
  const module = createQHooksModule({ client: createQHooksClient({ fetch }), account: async () => {
    // Standard Oak MCP account read: public address only. No key-file access.
    const result = await oakClient.callTool({ name: 'account', arguments: {} });
    if (result.isError) throw new Error('Oak account read failed.');
    return result.structuredContent ?? JSON.parse(result.content.filter(x => x.type === 'text').map(x => x.text).join('\n'));
  } });
  const result = {
    proof: await module.call('qhooks_qproof_check', { token }),
    trade: await module.call('qhooks_prepare_trade', { token, side: 'buy', amountIn: '1000000000000000' }),
    launch: await module.call('qhooks_prepare_launch', { name: 'Example', ticker: 'EX' }),
  };
  show(JSON.stringify(result, null, 2));
  return result;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.env.OAK_EXAMPLE_LIVE === '1') throw new Error('This example is fixture-only. Native Oak signing support requires a maintainer module; no wallet is opened.');
  console.log('Fixture mode: QHooks read/unsigned-plan adapter; no wallet, network, signing or execution.');
  const oak = fixtureOak();
  try { await qhooksExample(oak.client); } finally { await oak.close(); }
}
