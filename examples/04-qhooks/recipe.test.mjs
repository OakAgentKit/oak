// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, lstat } from 'node:fs/promises';
const directory = new URL('./recipe-package/', import.meta.url);
test('four data-only RH read recipes obey the documented oak-recipe/v1 constraints', async () => {
 const meta = JSON.parse(await readFile(new URL('package.json', directory)));assert.equal(meta.oakProject,'qhooks');assert.equal(meta.scripts,undefined);
 const files = await readdir(new URL('recipes/',directory));assert.equal(files.length,4);
 const addresses = new Set(['0xBea24499f82f1e018A4DFF5607b7c54141cBfbF8','0x9B6E579dD876c364bf232D2958d7CC45937809bf']);
 let size=0;
 for (const name of files) {
  assert.match(name,/^[a-z0-9-]+\.recipe\.json$/);const file=new URL('recipes/'+name,directory),stat=await lstat(file);assert.ok(stat.isFile()&&!stat.isSymbolicLink());assert.equal(stat.nlink,1);assert.ok(stat.size<=65536);size+=stat.size;
  const recipe=JSON.parse(await readFile(file));assert.equal(recipe.schema,'oak-recipe/v1');assert.equal(recipe.project,meta.oakProject);assert.match(recipe.name,/^[a-z0-9-]{1,40}$/);assert.equal(recipe.chainId,4663);assert.ok(addresses.has(recipe.contract));assert.equal(recipe.kind,'read');assert.equal(recipe.function.type,'function');assert.equal(recipe.function.stateMutability,'view');assert.deepEqual(recipe.inputs,recipe.function.inputs);assert.equal(recipe.approve,undefined);assert.match(recipe.description,/not reviewed by Oak/);
  assert.ok(['defaultFeeBps','feeBps','feeRecipient'].includes(recipe.function.name));assert.equal(recipe.function.outputs[0].type,recipe.function.name==='feeRecipient'?'address':recipe.function.name==='feeBps'?'uint256':'uint16');
 }
 assert.ok(size<4*1024*1024);
});
