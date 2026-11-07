// SPDX-License-Identifier: MIT
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js';
import { createBridge } from '@oakagentkit/addon/bridge';

export function disabled() { throw new Error('This example never signs transactions, sends, or renews.'); }
export const publicAddress = '0x1111111111111111111111111111111111111111';
export const inertSigner = {
  address: publicAddress, signMessage: disabled, signTransaction: disabled, signTypedData: disabled,
};

export async function connect({ signer = inertSigner, serverUrl = 'https://example.com',
  fetch, identity, display = () => {}, sender, fixtureOptions = {} } = {}) {
  const bridge = createBridge({
    network: 'mainnet', serverUrl, signer, fetch, identity, display,
    // Fixture senders model approval calls; the default sender cannot execute anything.
    ensureSubscribed: disabled, sender: sender ?? { send: disabled, signTypedData: disabled },
    recipes: async () => [], setup: disabled,
    ...fixtureOptions,
  });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: 'oak-read-only-example', version: '1.0.0' });
  try {
    await bridge.start(serverTransport);
    await client.connect(clientTransport);
  } catch (error) {
    await bridge.stop();
    throw error;
  }
  return { client, bridge, close: async () => { await client.close(); await bridge.stop(); } };
}

export async function readTool(client, name, args = {}) {
  if (!['find_token', 'quote', 'preview', 'balances', 'positions'].includes(name)) disabled();
  return toolResult(client, name, args);
}

export async function prepareAction(client, name, args) {
  return toolResult(client, 'oak_prepare', { name, arguments: args });
}

export async function executeAction(client, actionId) {
  return toolResult(client, 'oak_execute', { actionId });
}

async function toolResult(client, name, args) {
  const result = await client.callTool({ name, arguments: args });
  const text = result.content?.filter(item => item.type === 'text').map(item => item.text).join('\n');
  if (result.isError) throw new Error(text || 'Oak tool failed.');
  // 0.3.0 provides machine-readable data separately from its plain-text rendering.
  if (result.structuredContent) return result.structuredContent;
  if (!text) throw new Error('Oak returned no JSON text.');
  return JSON.parse(text);
}

export async function openExample() {
  if (process.env.OAK_EXAMPLE_LIVE !== '1') {
    console.log('Fixture mode: offline illustrative data; no wallet opened.');
    const { fixtureConnection } = await import('./fixtures.mjs');
    return fixtureConnection();
  }
  if (!process.env.OAK_SERVER_URL) throw new Error('Set OAK_SERVER_URL to the published Oak service URL.');
  // Local authentication messages only; never expose or export key material.
  const { loadSigner } = await import('@oakagentkit/addon/wallet');
  const signer = await loadSigner();
  return connect({ signer: { ...signer, signTransaction: disabled, signTypedData: disabled },
    serverUrl: process.env.OAK_SERVER_URL });
}
