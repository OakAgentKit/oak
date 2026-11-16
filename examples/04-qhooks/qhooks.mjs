// SPDX-License-Identifier: MIT
// Public read/prepare adapter. No key access, signer, approval, or transaction sender.
const ENDPOINT = 'https://qhooks.com/mcp';
const ADDRESS = /^0x[0-9a-fA-F]{40}$/;
const amount = { type: 'string', pattern: '^[1-9][0-9]{0,37}$' };
const address = { type: 'string', pattern: ADDRESS.source };
const chain = { type: 'string', enum: ['4663'], default: '4663' };
const schema = (properties, required = []) => ({ type: 'object', properties, required, additionalProperties: false });
const defs = [
  ['list_launches', 'Read QHooks launches', schema({ chain, limit: { type: 'integer', minimum: 1, maximum: 100 } })],
  ['token_info', 'Read a QHooks token market', schema({ chain, token: address }, ['token'])],
  ['quote', 'Quote a QHooks token swap', schema({ chain, token: address, side: { type: 'string', enum: ['buy', 'sell'] }, amountIn: amount, trader: address }, ['token', 'side', 'amountIn'])],
  ['qproof_check', 'Read stored QProof evidence', schema({ chain, token: address }, ['token'])],
  ['hooks_catalog', 'Browse the QHooks hook catalog', schema({ search: { type: 'string', maxLength: 100 } })],
  ['prepare_trade', 'Prepare an unsigned QHooks trade', schema({ chain, token: address, side: { type: 'string', enum: ['buy', 'sell'] }, amountIn: amount, slippageBps: { type: 'integer', minimum: 0, maximum: 9999 }, trader: address, referrer: address }, ['token', 'side', 'amountIn'])],
  ['prepare_launch', 'Prepare a QHooks launch review link', schema({ chain, name: { type: 'string', minLength: 1, maxLength: 32 }, ticker: { type: 'string', pattern: '^[A-Za-z0-9]{1,10}$' }, style: { type: 'string', maxLength: 100 }, referrer: address }, ['name', 'ticker'])],
];
export const QHOOKS_TOOLS = Object.freeze(defs.map(([name, title, inputSchema]) => ({
  name: 'qhooks_' + name, title, inputSchema,
  description: name.startsWith('prepare_')
    ? 'Return an unsigned QHooks plan only. Native Oak execution is unavailable until its local module guards are integrated; never pass this payload to generic send.'
    : 'Read QHooks public data. Preserve source timestamps, missing coverage and stale/not_checked states.',
  annotations: { title, readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: ['quote', 'prepare_trade'].includes(name) },
})));
export class QHooksError extends Error {
  constructor(message, { status, retryAfter, data } = {}) { super(message); this.name = 'QHooksError'; this.status = status; this.retryAfter = retryAfter; this.data = data; }
}
function wallet(value, name = 'wallet') {
  if (typeof value !== 'string' || !ADDRESS.test(value) || BigInt(value) === 0n) throw new QHooksError('Invalid ' + name + '.');
  return value.toLowerCase();
}
function argumentsFor(def, value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new QHooksError('Expected an argument object.');
  const out = { ...value };
  for (const name of Object.keys(out)) {
    const s = def.inputSchema.properties[name], v = out[name];
    if (!s) throw new QHooksError('Unknown argument: ' + name + '.');
    if (s.type === 'string' && (typeof v !== 'string' || s.minLength && v.length < s.minLength || s.maxLength && v.length > s.maxLength || s.pattern && !new RegExp(s.pattern).test(v)) ||
      s.type === 'integer' && (!Number.isInteger(v) || v < s.minimum || v > s.maximum) || s.enum && !s.enum.includes(v)) throw new QHooksError('Invalid ' + name + '.');
    if (s === address) out[name] = wallet(v, name);
  }
  for (const name of def.inputSchema.required) if (out[name] === undefined) throw new QHooksError('Missing ' + name + '.');
  if (def.inputSchema.properties.chain) out.chain ??= '4663';
  return out;
}
async function boundedJSON(response) {
  const reader = response.body?.getReader(); if (!reader) throw new QHooksError('Empty QHooks response.');
  let size = 0; const chunks = [];
  try { for (;;) { const { done, value } = await reader.read(); if (done) break; size += value.length; if (size > 262144) { await reader.cancel(); throw new QHooksError('QHooks response exceeds 256 KiB.'); } chunks.push(value); } }
  finally { reader.releaseLock(); }
  const bytes = new Uint8Array(size); let at = 0; for (const chunk of chunks) { bytes.set(chunk, at); at += chunk.length; }
  try { return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); } catch { throw new QHooksError('Invalid QHooks JSON response.'); }
}
export function createQHooksClient({ fetch = globalThis.fetch } = {}) {
  let serial = 0, session, initialization, protocol = '2025-06-18';
  async function rpc(method, params) {
    const id = ++serial;
    const response = await fetch(ENDPOINT, { method: 'POST', headers: { 'content-type': 'application/json', accept: 'application/json, text/event-stream', 'mcp-protocol-version': protocol, ...(session ? { 'mcp-session-id': session } : {}) },
      body: JSON.stringify({ jsonrpc: '2.0', id, method, params }), credentials: 'omit', redirect: 'error', signal: AbortSignal.timeout(15000) });
    if (!response.ok) throw new QHooksError('QHooks HTTP ' + response.status + '. No action was submitted.', { status: response.status, retryAfter: response.headers.get('retry-after') });
    const body = await boundedJSON(response);
    if (body.jsonrpc !== '2.0' || body.id !== id) throw new QHooksError('Mismatched QHooks response.');
    if (body.error) throw new QHooksError(body.error.message || 'QHooks RPC error.', { data: body.error });
    session = response.headers.get('mcp-session-id') || session;
    return { result: body.result, retryAfter: response.headers.get('retry-after') };
  }
  return { async call(name, args) {
    if (!defs.some(([n]) => n === name)) throw new QHooksError('Unsupported QHooks tool.');
    initialization ??= (async () => {
      const initializedReply = await rpc('initialize', { protocolVersion: protocol, capabilities: {}, clientInfo: { name: 'Oak QHooks read/prepare example', version: '1.0.0' } });
      if (!['2025-06-18', '2025-03-26'].includes(initializedReply.result?.protocolVersion)) throw new QHooksError('Unsupported QHooks MCP protocol version.');
      protocol = initializedReply.result.protocolVersion;
      const initialized = await fetch(ENDPOINT, { method: 'POST', headers: { 'content-type': 'application/json', accept: 'application/json, text/event-stream', 'mcp-protocol-version': protocol, ...(session ? { 'mcp-session-id': session } : {}) },
        body: JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }), credentials: 'omit', redirect: 'error', signal: AbortSignal.timeout(15000) });
      if (!initialized.ok) throw new QHooksError('QHooks initialization notification failed.', { status: initialized.status, retryAfter: initialized.headers.get('retry-after') });
    })();
    await initialization;
    const { result, retryAfter } = await rpc('tools/call', { name, arguments: args });
    let data = result?.structuredContent;
    if (data === undefined) { const text = result?.content?.filter(x => x.type === 'text').map(x => x.text).join('\n'); try { data = JSON.parse(text); } catch { throw new QHooksError('QHooks returned no JSON tool data.'); } }
    if (result.isError) throw new QHooksError(typeof data?.error === 'string' ? data.error : 'QHooks tool failed.', { data, retryAfter: data?.retryAfter || retryAfter });
    return data;
  } };
}
export function createQHooksModule({ client = createQHooksClient(), account, referrer } = {}) {
  if (referrer !== undefined) referrer = wallet(referrer, 'referrer');
  return { tools: QHOOKS_TOOLS, async call(name, args = {}) {
    const def = QHOOKS_TOOLS.find(d => d.name === name); if (!def) throw new QHooksError('Unsupported QHooks tool.');
    const input = argumentsFor(def, args), remote = name.slice('qhooks_'.length);
    if (remote.startsWith('prepare_')) {
      if (typeof account !== 'function') throw new QHooksError('Supply the public Oak account reader before preparing.');
      const owner = wallet((await account()).address, 'Oak account');
      if (input.trader !== undefined && input.trader !== owner) throw new QHooksError('trader must match the local Oak account.');
      if (remote === 'prepare_trade') input.trader = owner;
      input.referrer ??= referrer ?? owner;
    }
    const data = await client.call(remote, input);
    // Source evidence is passed through verbatim, including not_checked, stale,
    // coverage, fees, timestamps and errors. Unsigned bytes are never executable here.
    if (!remote.startsWith('prepare_')) return data;
    if (remote === 'prepare_launch') {
      let u; try { u = new URL(data.link); } catch { throw new QHooksError('Missing QHooks launch review link.'); }
      if (u.origin !== 'https://qhooks.com' || u.username || u.password) throw new QHooksError('Invalid QHooks launch review link.');
    } else if (String(data.chain) !== '4663' || data.trader?.toLowerCase() !== input.trader || data.token?.toLowerCase() !== input.token || data.amountIn !== input.amountIn || !Array.isArray(data.transactions) || !data.transactions.length || data.transactions.length > 8 || data.transactions.some(t => !ADDRESS.test(t.to || '') || !/^0x(?:[0-9a-f]{2})+$/i.test(t.data || '') || !/^(?:0x[0-9a-f]+|[0-9]+)$/i.test(String(t.value ?? '')))) throw new QHooksError('QHooks unsigned plan does not match the request.');
    return { status: 'prepared_only', executionSupported: false, source: 'QHooks', data,
      next: 'Review the unsigned plan. Native Oak execution requires Oak-maintained pinned module guards and the normal oak_prepare summary, yes/no confirmation and oak_execute checks. This adapter never signs or sends.' };
  } };
}
