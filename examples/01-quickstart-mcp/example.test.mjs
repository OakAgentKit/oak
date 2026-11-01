// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { fixtureConnection } from '../shared/fixtures.mjs';
import { listTools } from './index.mjs';
test('real packaged add-on connects over MCP and exposes Pons creator schemas', async () => {
  const calls = [];
  const connection = await fixtureConnection({ calls });
  try {
    const tools = await listTools(connection.client);
    const hasFinder = tools.some(tool => tool.name === 'find_tool');
    assert.equal(tools.length, hasFinder ? 82 : 100);
    for (const name of ['balances', 'positions', 'quote', ...(hasFinder ? ['find_tool', 'run_tool'] : ['preview']), 'oak_setup',
      'pons_launch_options', 'pons_transfer_creator_fee_recipient', 'pons_set_buyback']) {
      let schema = tools.find(tool => tool.name === name)?.inputSchema;
      if (!schema) {
        const result = await connection.client.callTool({ name: 'find_tool', arguments: { query: name } });
        const found = JSON.parse(result.content.filter(item => item.type === 'text').map(item => item.text).join('\n'));
        schema = found.results.find(tool => tool.name === name)?.inputSchema;
      }
      assert.equal(schema?.type, 'object', name);
    }
    assert.deepEqual(calls, []); // Discovery does not contact the hosted service.
  } finally { await connection.close(); }
});
