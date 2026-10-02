import { lstatSync, readFileSync, realpathSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const semver = /^\d+\.\d+\.\d+$/;
const digest = /^[0-9a-f]{64}$/;

export async function packagePins(root, version) {
  if (!semver.test(version)) throw new Error('exact stable Shell version required');
  const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));
  if (pkg.name !== 'gentle-pi' || pkg.version !== version ||
      pkg.bin?.['gentle-shell'] !== 'bin/gentle-shell.mjs' ||
      pkg.engines?.node !== '>=22.19.0' ||
      pkg.peerDependencies?.['@earendil-works/pi-coding-agent'] !== '>=0.99.1') {
    throw new Error('unsupported Shell package, entry point, or engine contract');
  }
  const installer = await import(pathToFileURL(join(root, 'scripts/gentle-ai-installer.mjs')));
  if (!semver.test(installer.INSTALLER_VERSION)) throw new Error('stable private Gentle AI required');
  const pins = { version: installer.INSTALLER_VERSION };
  for (const arch of ['amd64', 'arm64']) {
    const asset = installer.resolveGentleAiReleaseAsset('linux', arch === 'amd64' ? 'x64' : arch);
    const name = `gentle-ai_${pins.version}_linux_${arch}.tar.gz`;
    if (asset.name !== name || asset.executable !== 'gentle-ai' ||
        asset.url !== `https://github.com/Gentleman-Programming/gentle-ai/releases/download/v${pins.version}/${name}` ||
        !digest.test(asset.sha256) || !digest.test(asset.binarySha256)) {
      throw new Error(`unsupported private release contract for ${arch}`);
    }
    pins[arch] = { version: pins.version, asset: name, assetSha256: asset.sha256, binarySha256: asset.binarySha256 };
  }
  return pins;
}

export function verifyManagedPi(root, version) {
  if (!semver.test(version) || !root || realpathSync(root) !== resolve(root)) {
    throw new Error('canonical managed Pi root/version required');
  }
  const pi = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));
  const cli = join(root, 'dist/bundle/cli.js');
  if (pi.name !== '@earendil-works/pi-coding-agent' || pi.version !== version ||
      pi.bin?.pi !== 'dist/bundle/cli.js' || realpathSync(cli) !== cli ||
      !lstatSync(cli).isFile()) throw new Error('managed Pi differs from policy');
  return cli;
}

export async function verifyBundle(root, version, manifest) {
  const pins = await packagePins(root, version);
  const arch = process.arch === 'x64' ? 'amd64' : process.arch;
  if (process.platform !== 'linux' || !pins[arch] ||
      JSON.stringify(manifest) !== JSON.stringify(pins[arch])) {
    throw new Error('private bundle differs from managed architecture/policy');
  }
  function rejectPeerCopies(modules) {
    let entries;
    try { entries = readdirSync(modules, { withFileTypes: true }); }
    catch (error) { if (error.code === 'ENOENT') return; throw error; }
    for (const entry of entries) {
      if (entry.name === '@earendil-works' || entry.name === 'typebox') {
        throw new Error(`duplicate managed Pi dependency: ${join(modules, entry.name)}`);
      }
      if (entry.isDirectory() && !entry.name.startsWith('.')) {
        if (entry.name.startsWith('@')) rejectPeerCopies(join(modules, entry.name));
        else rejectPeerCopies(join(modules, entry.name, 'node_modules'));
      }
    }
  }
  rejectPeerCopies(join(root, 'node_modules'));
  rejectPeerCopies(join(root, '..'));
  const resolver = await import(pathToFileURL(join(root, 'runtime/gentle-ai-binary.mjs')));
  // Supply the actual upstream environment contract, not an assumed path API.
  const environment = { env: {}, home: join(root, '.unused-verification-home') };
  const binary = resolver.resolveGentleAiBinary(root, 'linux', readFileSync, environment);
  if (binary !== join(resolve(root), '.gentle-ai', `v${pins.version}`, 'gentle-ai')) {
    throw new Error('resolver did not select the package-private binary');
  }
  return resolver;
}

export function rejectOverrides(resolver, packageRoot, environment = process.env,
  registrations = [resolver.gentleAiDevBinaryRegistrationPath()]) {
  for (const key of ['GENTLE_PI_GENTLE_AI_DEV_BINARY', 'GENTLE_SHELL_GENTLE_AI_BIN',
    'GENTLE_SHELL_GENTLE_AI_PIN', 'GENTLE_SHELL_GENTLE_AI_INSTALLER']) {
    if (environment[key] !== undefined) throw new Error(`managed Shell rejects ${key}`);
  }
  for (const registration of registrations) {
    try {
      lstatSync(registration);
      throw new Error(`managed Shell rejects development registration: ${registration}`);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
  if (packageRoot !== undefined) {
    throw new Error('managed Shell rejects --package-root');
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [mode, root, version, manifestFile] = process.argv.slice(2);
  try {
    if (mode === 'pins') console.log(JSON.stringify(await packagePins(root, version)));
    else if (mode === 'verify') await verifyBundle(root, version, JSON.parse(readFileSync(manifestFile, 'utf8')));
    else if (mode === 'pi') console.log(verifyManagedPi(root, version));
    else throw new Error('unknown bundle check mode');
  } catch (error) {
    console.error(`Gentle Shell: ${error.message}`);
    process.exitCode = 1;
  }
}
