// Execute the vendored dispatch, not a rewritten approximation. No server,
// initialization, CLI, credentials or database is reachable from this harness.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { test } from 'node:test';
import vm from 'node:vm';

const root = new URL('../../config/gentle-shell/agent/extensions/engram/', import.meta.url);
const source = readFileSync(new URL('index.ts', root), 'utf8');
// Parse the complete 0.2.0 source, but execute only its schema and dispatcher.
const javascript = stripTypeScriptTypes(source);
function section(start, end) {
  const first = javascript.indexOf(start);
  const last = javascript.indexOf(end, first);
  assert.ok(first >= 0 && last > first, `missing adapter boundary: ${start}`);
  return javascript.slice(first, last);
}
const scalar = type => options => ({ type, ...options });
const context = vm.createContext({
  URLSearchParams,
  Type: {
    String: scalar('string'), Number: scalar('number'), Boolean: scalar('boolean'),
    Integer: scalar('integer'), Object: properties => ({ properties }),
    Optional: schema => ({ ...schema, optional: true }),
  },
  getSessionId: () => undefined,
  project: 'fixture',
  WRITE_TARGET_TOOLS: new Set(),
  engramFetch: () => { throw new Error('real transport is forbidden'); },
});
vm.runInContext([
  section('const optionalString', 'function queryString'),
  section('function queryString', 'async function archiveCompactionSummary'),
  section('async function callMemoryTool', 'function unreachableMessage'),
  'globalThis.dispatch = callMemoryTool; globalThis.schemas = MEMORY_TOOL_SCHEMAS;',
].join('\n'), context);

test('0.2.0 schemas require an explicit mutation owner', () => {
  for (const name of ['mem_update', 'mem_delete']) {
    assert.equal(context.schemas[name].properties.expected_project.type, 'string');
    assert.equal(context.schemas[name].properties.expected_project.optional, undefined);
  }
});

test('actual update and delete dispatch encode expected_project and preserve payload', async () => {
  const calls = [];
  const fetch = async (path, options) => { calls.push({ path, options }); return { id: 42 }; };
  await context.dispatch('mem_update', { id: 42, expected_project: 'owner/name', title: 'new title' }, {}, fetch);
  await context.dispatch('mem_delete', { id: 42, expected_project: 'owner/name', hard_delete: true }, {}, fetch);
  assert.equal(calls[0].path, '/observations/42?expected_project=owner%2Fname');
  assert.equal(calls[0].options.method, 'PATCH');
  assert.equal(calls[0].options.body.title, 'new title');
  assert.equal(calls[0].options.body.expected_project, undefined);
  assert.equal(calls[1].path, '/observations/42?hard=true&expected_project=owner%2Fname');
  assert.equal(calls[1].options.method, 'DELETE');
});

test('dispatch propagates mocked 400/409/404 without retry or a successful mutation', async () => {
  for (const name of ['mem_update', 'mem_delete']) {
    for (const [owner, id, status] of [[undefined, 42, 400], ['', 42, 400], ['other', 42, 409], ['fixture', 999, 404]]) {
      let calls = 0;
      const fetch = async path => {
        calls++;
        const url = new URL(path, 'http://fixture.invalid');
        const expected = url.searchParams.get('expected_project');
        const actual = !expected ? 400 : expected !== 'fixture' ? 409 : 404;
        assert.equal(actual, status);
        throw Object.assign(new Error('mocked rejection'), { status });
      };
      await assert.rejects(context.dispatch(name, { id, expected_project: owner }, {}, fetch), error => error.status === status);
      assert.equal(calls, 1);
    }
  }
});

test('runtime hashes manifest provenance and image-owned pins agree', () => {
  const helper = readFileSync(new URL('../../install/lib/gentle-shell-provision.mjs', import.meta.url), 'utf8');
  const manifest = readFileSync(new URL('SHA256SUMS', root), 'utf8').trim().split('\n');
  assert.equal(manifest.length, 5);
  for (const line of manifest) {
    const [hash, name] = line.split('  ');
    assert.equal(createHash('sha256').update(readFileSync(new URL(name, root))).digest('hex'), hash);
    assert.ok(helper.includes(`['${name}', '${hash}']`));
  }
  const provenance = readFileSync(new URL('PROVENANCE.md', root), 'utf8');
  assert.ok(provenance.includes('15a2f78885d7ad8ced23b2d1d88383e9bb472c17'));
  assert.ok(provenance.includes('version 0.2.0'));
  const policy = readFileSync(new URL('../../tool-versions.conf', import.meta.url), 'utf8');
  assert.match(policy, /^TOOL_ENGRAM_VERSION="3\.0\.0"$/m);
  assert.match(policy, /^LOCK_ENGRAM_VERSION="3\.0\.0"$/m);
});
