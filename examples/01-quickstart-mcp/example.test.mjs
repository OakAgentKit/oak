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
    assert.equal(tools.length, 100);
    for (const name of ['balances', 'positions', 'quote', 'preview', 'oak_setup',
      'pons_launch_options', 'pons_transfer_creator_fee_recipient', 'pons_set_buyback']) {
      assert.equal(tools.find(tool => tool.name === name)?.inputSchema.type, 'object', name);
    }
    assert.deepEqual(calls, []); // Discovery does not contact the hosted service.
  } finally { await connection.close(); }
});
