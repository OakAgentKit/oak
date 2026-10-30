// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { disabled, readTool } from '../shared/client.mjs';
import { fixtureConnection } from '../shared/fixtures.mjs';
test('positive controls: action attempts and tool errors are detected', async () => {
  assert.throws(disabled, /never signs/);
  const connection = await fixtureConnection();
  try {
    await assert.rejects(readTool(connection.client, 'swap'), /never signs/);
    const action = await connection.client.callTool({ name: 'swap', arguments: { quoteId: 'deliberate-action' } });
    assert.equal(action.isError, true);
    const unknown = await connection.client.callTool({ name: 'unknown', arguments: {} });
    assert.equal(unknown.isError, true);
    await assert.rejects(readTool({ callTool: async () => ({ isError: true, content: [{ type: 'text', text: 'fixture failure' }] }) }, 'balances'), /fixture failure/);
  } finally { await connection.close(); }
});
