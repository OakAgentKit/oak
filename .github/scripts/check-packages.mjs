/* global AbortSignal */
// Only exact-version npm 404s are a prelaunch skip. Outages/auth errors fail.
import { readFileSync, appendFileSync } from 'node:fs';
const manifest = JSON.parse(readFileSync(new URL('../../examples/package.json', import.meta.url)));
const registry = process.env.OAK_CI_REGISTRY ?? 'https://registry.npmjs.org';
const missing = [];
for (const name of ['@oakagentkit/core', '@oakagentkit/addon']) {
  const version = manifest.dependencies[name];
  if (!/^\d+\.\d+\.\d+(?:-[\w.-]+)?$/.test(version)) throw new Error(`${name}: expected an exact version`);
  const response = await fetch(`${registry}/${encodeURIComponent(name)}/${version}`, { signal: AbortSignal.timeout(30000) });
  if (response.status === 404) missing.push(`${name}@${version}`);
  else {
    if (!response.ok) throw new Error(`npm availability check failed with HTTP ${response.status}`);
    const pkg = await response.json();
    if (pkg.name !== name || pkg.version !== version) throw new Error(`npm returned unexpected metadata for ${name}`);
  }
}
if (missing.length) {
  const notice = `Examples skipped: unpublished npm versions: ${missing.join(', ')}. Set repository variable OAK_EXAMPLES_REQUIRE_PUBLISHED=true to make this a failure at launch.`;
  console.log(`::notice::${notice}`);
  if (process.env.OAK_EXAMPLES_REQUIRE_PUBLISHED === 'true') throw new Error(notice);
} else console.log('Exact Oak npm versions are published; install and test examples.');
if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, `ready=${missing.length === 0}\n`);
