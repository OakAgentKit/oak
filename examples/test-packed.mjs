// SPDX-License-Identifier: MIT
import { mkdtempSync, cpSync, readdirSync, realpathSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = fileURLToPath(new URL('.', import.meta.url));
const [core, addon] = process.argv.slice(2);
if (!core || !addon || process.versions.node.split('.')[0] !== '22') {
  throw new Error('Use Node 22: node test-packed.mjs CORE.tgz ADDON.tgz');
}
const archives = [core, addon].map(path => realpathSync(resolve(path)));
const work = mkdtempSync(join(root, '.packed-'));
for (const entry of readdirSync(root)) {
  if (/^(01-|02-|03-|shared$|test$|package.json$|test-packed.mjs$|README.md$|eval-design.md$|LICENSE$|\.gitignore$)/.test(entry)) {
    cpSync(join(root, entry), join(work, entry), { recursive: true });
  }
}
writeFileSync(join(work, 'empty-npmrc'), '');
const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';
function run(command, args) {
  const result = spawnSync(command, args, { cwd: work, stdio: 'inherit', env: { ...process.env, npm_config_userconfig: '/dev/null', npm_config_globalconfig: join(work, 'empty-npmrc') } });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
// No workspace links, package lifecycle hooks, user npm config, wallet or RPC.
run(npm, ['install', '--ignore-scripts', '--no-audit', '--no-fund', '--package-lock=false',
  '--cache', join(root, '.cache'), ...archives]);
run(npm, ['test']);
console.log(`Packed examples passed. Installed sandbox: ${work}`);
