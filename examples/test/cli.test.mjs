// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
for (const [directory, expected] of [
  ['01-quickstart-mcp', /100 tools/],
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
    assert.match(result.stdout, expected);
  });
}
