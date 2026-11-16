// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createQHooksClient, createQHooksModule, QHOOKS_TOOLS } from './qhooks.mjs';
import { fixtures, fixtureFetch, fixtureOak, wallet, token } from './fixtures.mjs';
import { qhooksExample } from './index.mjs';
const other = '0x4444444444444444444444444444444444444444';
function setup(options = {}) {
 const calls = []; const client = createQHooksClient({ fetch: fixtureFetch({ calls, ...options }) });
 const module = createQHooksModule({ client, account: async () => ({ address: wallet }), ...options });
 return { calls, module };
}
test('seven explicit read/prepare tools; no signing or submit tool', () => {
 assert.deepEqual(QHOOKS_TOOLS.map(t => t.name), ['qhooks_list_launches','qhooks_token_info','qhooks_quote','qhooks_qproof_check','qhooks_hooks_catalog','qhooks_prepare_trade','qhooks_prepare_launch']);
 assert.ok(QHOOKS_TOOLS.every(t => t.annotations.readOnlyHint && t.annotations.title === t.title));
});
test('MCP initializes once with client identity then reads preserve stale, missing and coverage evidence', async () => {
 const f = setup();
 assert.deepEqual(await f.module.call('qhooks_qproof_check', { token }), fixtures.qproof_check);
 assert.deepEqual(await f.module.call('qhooks_token_info', { token }), fixtures.token_info);
 assert.deepEqual(await f.module.call('qhooks_hooks_catalog'), fixtures.hooks_catalog);
 assert.equal(f.calls.filter(c => c.method === 'initialize').length, 1);
 assert.equal(f.calls[0].params.clientInfo.name, 'Oak QHooks read/prepare example');
 assert.equal(f.calls[1].headers['mcp-session-id'], 'offline-fixture-only');
 assert.equal(f.calls.find(c => c.method === 'tools/call').params.arguments.chain, '4663');
 assert.equal(f.calls[1].method, 'notifications/initialized');
});
test('raw integer amounts and RH exact-address arguments validate before HTTP', async () => {
 const f = setup();
 for (const args of [{ token, side:'buy', amountIn:0.1 },{ token, side:'buy', amountIn:'1.5' },{ token, side:'buy', amountIn:'-1' },{ token, side:'buy', amountIn:'0' },{ token, side:'buy', amountIn:'1', chain:'8453' },{ token:'QHOOKS', side:'buy', amountIn:'1' },{ token, side:'buy', amountIn:'1', private_key:'forbidden' }]) await assert.rejects(f.module.call('qhooks_quote', args));
 assert.equal(f.calls.length, 0);
});
test('referrer precedence explicit then configured then local wallet, with trader bound to Oak account', async () => {
 for (const [options,args,expected] of [[{}, {},wallet],[{referrer:other},{},other],[{referrer:other},{referrer:token},token]]) {
  const f=setup(options),r=await f.module.call('qhooks_prepare_trade',{token,side:'buy',amountIn:fixtures.prepare_trade.amountIn,...args});
  assert.equal(r.status,'prepared_only');assert.equal(r.executionSupported,false);assert.equal(r.data.trader,wallet);assert.equal(r.data.amountIn,fixtures.prepare_trade.amountIn);
  assert.equal(f.calls.at(-1).params.arguments.referrer,expected);assert.equal(f.calls.at(-1).params.arguments.trader,wallet);
 }
 const f=setup();await assert.rejects(f.module.call('qhooks_prepare_trade',{token,side:'buy',amountIn:'1',trader:other}),/local Oak account/);assert.equal(f.calls.length,0);
});
test('launch prepares only an allowlisted review link and maps referral', async () => {
 const f=setup({referrer:other});const result=await f.module.call('qhooks_prepare_launch',{name:'Example',ticker:'EX'});
 assert.equal(result.executionSupported,false);assert.equal(f.calls.at(-1).params.arguments.referrer,other);
 for (const link of ['javascript:alert(1)','https://qhooks.com.evil.test/launch','https://user:pass@qhooks.com/launch']) {
  const invalid=setup({responses:{...fixtures,prepare_launch:{link}}});await assert.rejects(invalid.module.call('qhooks_prepare_launch',{name:'Example',ticker:'EX'}),/review link/);
 }
});
test('changed chain/wallet/token/amount or missing unsigned transaction stops preparation', async () => {
 for (const changed of [{chain:'8453'},{trader:other},{token:other},{amountIn:'2'},{transactions:[]}]) {
  const f=setup({responses:{...fixtures,prepare_trade:{...fixtures.prepare_trade,...changed}}});
  await assert.rejects(f.module.call('qhooks_prepare_trade',{token,side:'buy',amountIn:fixtures.prepare_trade.amountIn}),/does not match/);
 }
});
test('QHooks tool errors and HTTP Retry-After remain explicit; no automatic retry', async () => {
 let calls=0;const client=createQHooksClient({fetch:async()=>{calls++;return Response.json({error:'limit'}, {status:429,headers:{'retry-after':'60'}});}});
 await assert.rejects(client.call('qproof_check',{chain:'4663',token}),e=>e.status===429&&e.retryAfter==='60');assert.equal(calls,1);
 const errorClient=createQHooksClient({fetch:async(_u,o)=>{const r=JSON.parse(o.body);if(r.method==='notifications/initialized')return new Response(null,{status:202});return Response.json({jsonrpc:'2.0',id:r.id,result:r.method==='initialize'?{protocolVersion:'2025-06-18'}:{isError:true,structuredContent:{error:'price_unavailable',retryAfter:15}}});}});
 await assert.rejects(errorClient.call('quote',{chain:'4663',token,side:'buy',amountIn:'1'}),e=>e.message==='price_unavailable'&&e.retryAfter===15);
});
test('bounded transport rejects mismatched IDs, redirects and unsupported tools', async () => {
 const client=createQHooksClient({fetch:async(_u,o)=>{assert.equal(o.credentials,'omit');assert.equal(o.redirect,'error');return Response.json({jsonrpc:'2.0',id:999,result:{}});}});
 await assert.rejects(client.call('list_launches',{}),/Mismatched/);
 await assert.rejects(client.call('eth_sendRawTransaction',{}),/Unsupported/);
 const large=createQHooksClient({fetch:async()=>new Response('x'.repeat(262145))});await assert.rejects(large.call('list_launches',{}),/256 KiB/);
});
test('example uses account read only; CLI runs without sockets, wallet or execution', async () => {
 const oak=fixtureOak(),calls=[];const original=oak.client.callTool;oak.client.callTool=async req=>{calls.push(req.name);return original(req);};
 const result=await qhooksExample(oak.client,{show:()=>{}});assert.equal(result.proof.state,'not_checked');assert.equal(result.trade.executionSupported,false);assert.deepEqual(calls,['account','account']);
 const guard='data:text/javascript,'+encodeURIComponent("import net from 'node:net';const no=()=>{throw Error('network forbidden')};net.Socket.prototype.connect=no;globalThis.fetch=no;");
 const r=spawnSync(process.execPath,['--import',guard,new URL('./index.mjs',import.meta.url).pathname],{encoding:'utf8',timeout:30000,env:{PATH:process.env.PATH,OAK_EXAMPLE_LIVE:'0'}});
 assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/Fixture mode/);assert.match(r.stdout,/prepared_only/);assert.doesNotMatch(r.stdout,/submitted|transactionHash/);
});
