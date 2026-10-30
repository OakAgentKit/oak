// SPDX-License-Identifier: MIT
import { pathToFileURL } from 'node:url';
import { openExample } from '../shared/client.mjs';
export async function listTools(client) {
  const tools = [];
  let cursor;
  do {
    const page = await client.listTools(cursor ? { cursor } : {});
    tools.push(...page.tools);
    cursor = page.nextCursor;
  } while (cursor);
  return tools;
}
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const connection = await openExample();
  try {
    const tools = await listTools(connection.client);
    console.log(`${tools.length} tools (names and JSON input schemas):`);
    console.log(JSON.stringify(tools, null, 2));
  } finally { await connection.close(); }
}
