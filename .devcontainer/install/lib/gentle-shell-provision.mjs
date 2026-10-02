// Read-only Shell validation. Configuration copying belongs to setup.sh.
import { createHash } from 'node:crypto';
import { lstatSync, readFileSync, readdirSync, realpathSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const adapter = 'agent/extensions/engram';
// Immutable runtime trust metadata, not a configuration baseline. These pins
// match the version-controlled adapter's SHA256SUMS at Engram v3.0.0/0.2.0.
const hashes = new Map([
  ['index.ts', '387555a903d64f2d4c9145499bd34d3f5c616f310e0bc89f49c23e2f2189880f'],
  ['compaction-recovery.js', 'd9d619b48824f9c6b3c4547c27b115ee6bc3fa82bb43d85c9afb2d9e5fa96d7c'],
  ['memory-tool-chrome.js', '7caac650bfc4a68e375cc05b4175ed9b4379dec754fbadb47b5d8113a65a4e2f'],
  ['private-redaction.js', 'aa6f3d397afdee8b2a561d49cb08cf4b0b07f9647005addf53a4b84d58731473'],
  ['LICENSE', '09608597ddda4e5f9033ac407a0d401986d96376c47f6d46789ca38db672dc15'],
]);
const files = ['config.json', 'agent/settings.json',
  ...[...hashes.keys()].map(name => `${adapter}/${name}`), `${adapter}/SHA256SUMS`, `${adapter}/PROVENANCE.md`];

function inspect(path) {
  try { return lstatSync(path); }
  catch (error) { if (error.code === 'ENOENT') return undefined; throw error; }
}

function assertPath(path, directory = false) {
  const stat = inspect(path);
  if (stat && (stat.isSymbolicLink() || (directory ? !stat.isDirectory() : !stat.isFile()))) {
    throw new Error(`unsafe managed Shell path: ${path}`);
  }
  return stat;
}

function assertParents(path) {
  for (let parent = dirname(path); parent !== dirname(parent); parent = dirname(parent)) {
    assertPath(parent, true);
  }
}

function jsonObject(path) {
  if (!assertPath(path)) return undefined;
  const value = JSON.parse(readFileSync(path, 'utf8'));
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error(`JSON object required: ${path}`);
  return value;
}

/** Inspect only the isolated profile. Never create, copy, repair or migrate files. */
export function validateShell(root, required = true) {
  root = resolve(root);
  assertParents(root);
  if (assertPath(root, true) && realpathSync(root) !== root) throw new Error(`noncanonical Shell directory: ${root}`);
  if (inspect(join(root, '.provisioning.lock'))) throw new Error('Shell provisioning lock is busy; finish container postCreate setup');
  for (const relative of files) {
    const path = join(root, relative);
    assertParents(path);
    if (!assertPath(path)) {
      if (required) throw new Error(`Shell configuration is not provisioned: ${relative}; automatic container postCreate setup must finish; recreate through the host Task workflow`);
      continue;
    }
    const hash = relative.startsWith(`${adapter}/`) ? hashes.get(relative.slice(adapter.length + 1)) : undefined;
    if (hash && createHash('sha256').update(readFileSync(path)).digest('hex') !== hash) {
      throw new Error(`existing adapter differs from pinned source: ${relative}; stop Shell, review and move only agent/extensions/engram outside extensions before postCreate setup; see .devcontainer/docs/gentle-shell.md#adapter-upgrade-recovery; preferences and Engram storage must remain in place`);
    }
  }
  const config = jsonObject(join(root, 'config.json'));
  if (config && config.home !== 'isolated') throw new Error('managed Shell requires isolated launcher configuration');
  const settings = jsonObject(join(root, 'agent/settings.json'));
  for (const field of ['extensions', 'packages']) {
    if (settings?.[field] !== undefined && !Array.isArray(settings[field])) throw new Error(`invalid Shell ${field}`);
  }
  return join(root, 'agent');
}

function validateSeedSource(source) {
  validateShell(source);
  function inspectTree(directory, relative = '') {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const name = relative ? `${relative}/${entry.name}` : entry.name;
      if (entry.isDirectory() && files.some(file => file.startsWith(`${name}/`))) {
        inspectTree(join(directory, entry.name), name);
      } else if (!entry.isFile() || !files.includes(name)) {
        throw new Error(`unreviewed Shell baseline path: ${name}`);
      }
    }
  }
  inspectTree(source);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const [mode, first, second] = process.argv.slice(2);
    if (mode === 'pre-seed' && first && second && process.argv.length === 5) {
      validateSeedSource(resolve(first));
      validateShell(second, false);
    } else if (mode === 'check' && first && process.argv.length === 4) validateShell(first);
    else throw new Error('expected pre-seed BASELINE PROFILE or check PROFILE');
  } catch (error) {
    console.error(`Gentle Shell validation: ${error.message}`);
    process.exitCode = 1;
  }
}
