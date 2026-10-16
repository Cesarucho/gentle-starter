'use strict';

// Validate installed files, not require.resolve paths that may escape to HOME.
const fs = require('node:fs');
const path = require('node:path');
const [root, version, arch] = process.argv.slice(2);
const scope = path.join(root, 'lib/node_modules/@colbymchenry');
const name = `codegraph-linux-${arch}`;
const mainDirectory = path.join(scope, 'codegraph');
const bundle = fs.realpathSync(path.dirname(require.resolve(`@colbymchenry/${name}/package.json`, {
  paths: [mainDirectory],
})));
const canonicalRoot = fs.realpathSync(root);
if (!bundle.startsWith(canonicalRoot + path.sep)) {
  throw new Error('CodeGraph platform bundle resolved outside its image-owned installation');
}

function manifest(directory, expectedName) {
  const value = JSON.parse(fs.readFileSync(path.join(directory, 'package.json'), 'utf8'));
  if (value.name !== `@colbymchenry/${expectedName}` || value.version !== version) {
    throw new Error(`CodeGraph package identity/version mismatch: ${expectedName}`);
  }
  return value;
}

const main = manifest(mainDirectory, 'codegraph');
const platform = manifest(bundle, name);
if (main.optionalDependencies?.[`@colbymchenry/${name}`] !== version ||
    !platform.os?.includes('linux') || !platform.cpu?.includes(arch)) {
  throw new Error('CodeGraph platform dependency does not match the exact policy');
}
for (const executable of ['node', 'bin/codegraph']) {
  fs.accessSync(path.join(bundle, executable), fs.constants.X_OK);
}
fs.accessSync(path.join(bundle, 'lib/dist/bin/codegraph.js'), fs.constants.R_OK);
const files = fs.readdirSync(path.join(bundle, 'lib/dist'), { recursive: true });
if (!files.some(file => file.endsWith('.wasm')) || !files.some(file => file.endsWith('schema.sql'))) {
  throw new Error('CodeGraph bundle is missing its parser grammars or SQLite schema');
}
console.log(path.relative(canonicalRoot, bundle));
