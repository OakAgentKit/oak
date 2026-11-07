// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
for (const [directory, expected] of [
  ['01-quickstart-mcp', null],
  ['02-preview-sign-swap', /stopped\s*$/],
  ['03-portfolio-agent', /"humanAmount": "25"/],
]) {
  test(`${directory} runs offline as a CLI without a terminal`, () => {
    const result = spawnSync(process.execPath, [fileURLToPath(new URL(`../${directory}/index.mjs`, import.meta.url))], {
      encoding: 'utf8', timeout: 10000,
      env: { PATH: process.env.PATH, OAK_EXAMPLE_LIVE: '0' },
    });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Fixture mode/);
    if (directory === '02-preview-sign-swap') {
      assert.match(result.stdout, /Leaves wallet:/);
      assert.match(result.stdout, /Comes back:/);
      assert.match(result.stdout, /Token approval:/);
      assert.match(result.stdout, /Action: oa_/);
      assert.match(result.stdout, /Expires: .*Z/);
      assert.doesNotMatch(result.stdout, /execution requested after yes/);
    }
    if (expected) assert.match(result.stdout, expected);
    else {
      const output = /^(\d+) tools \(names and JSON input schemas\):\n([\s\S]+)$/m.exec(result.stdout);
      assert.ok(output, 'quickstart prints the tool count and JSON schemas');
      const tools = JSON.parse(output[2]);
      assert.equal(Number(output[1]), tools.length);
      for (const name of ['balances', 'find_tool', 'oak_receipts']) {
        assert.equal(tools.find(tool => tool.name === name)?.inputSchema.type, 'object', name);
      }
    }
  });
}
