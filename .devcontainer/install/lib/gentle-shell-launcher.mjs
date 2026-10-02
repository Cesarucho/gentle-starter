#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { rejectOverrides, verifyBundle, verifyManagedPi } from './gentle-shell-bundle.mjs';
import { validateShell } from './gentle-shell-provision.mjs';

try {
  const directory = dirname(fileURLToPath(import.meta.url));
  const root = join(directory, 'lib/node_modules/gentle-pi');
  const policy = JSON.parse(readFileSync(join(directory, 'bundle.json'), 'utf8'));
  const resolver = await verifyBundle(root, policy.version, policy.manifest, policy.piVersion);
  const native = await import(pathToFileURL(join(root, 'runtime/gentle-shell-launcher.mjs')));
  const args = native.parseLauncherArgs(process.argv.slice(2));
  if (args.error) throw new Error(args.error);
  const state = join(homedir(), '.gentle-shell');
  const agent = join(state, 'agent');
  rejectOverrides(resolver, args.packageRoot, process.env,
    [resolver.gentleAiDevBinaryRegistrationPath(), join(state, 'gentle-ai/dev-binary.json')]);
  if (args.link || (args.home !== undefined && resolve(args.home) !== agent) ||
      (args.command === 'home' && args.commandArgs.length)) {
    throw new Error('managed Shell uses only ~/.gentle-shell/agent; linked/custom homes are not supported');
  }
  for (const key of ['GENTLE_SHELL_PI', 'GENTLE_SHELL_HOME', 'GENTLE_SHELL_CONFIG', 'GENTLE_PI_CONFIG_HOME']) {
    if (process.env[key] !== undefined) throw new Error(`managed Shell rejects ${key}`);
  }
  const cli = verifyManagedPi(policy.piRoot, policy.piVersion);
  const probe = spawnSync(process.execPath, [cli, '--version'], {
    encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 15000,
    env: { ...process.env, PI_CODING_AGENT_DIR: agent, GENTLE_PI_AGENT_HOME: agent },
  });
  const checked = native.checkPiVersion(probe.stdout ?? '');
  if (probe.error || probe.status !== 0 || !checked.ok || checked.version !== policy.piVersion) {
    throw new Error('managed Pi CLI version differs from policy or version probe failed');
  }
  if (args.help) {
    console.log('Usage: gentle-shell [--isolated] [-- pi-args...]\nManaged isolated home; automatic container postCreate setup owns configuration. Native setup/link/runtime overrides are disabled.');
  } else if (args.version) {
    console.log(native.describeVersion({ gentlePiVersion: policy.version, piVersion: policy.piVersion,
      home: { mode: 'isolated', dir: agent } }));
  } else if (args.command === 'home') {
    console.log(`isolated ${agent}`);
  } else {
    if (args.command === 'setup') throw new Error('Shell configuration belongs to automatic container postCreate setup, not gentle-shell setup');
    validateShell(state);
      const settings = readFileSync(join(agent, 'settings.json'), 'utf8');
      const declaration = native.findGentlePiDeclaration(settings, { agentDir: agent,
        readPackageName: path => JSON.parse(readFileSync(join(path, 'package.json'), 'utf8')).name });
      if (declaration) throw new Error('remove the conflicting gentle-pi settings declaration; managed Shell injects its exact package');
      const invocation = native.buildPiInvocation({ runtime: { command: process.execPath, args: [cli] },
        home: { mode: 'isolated', dir: agent }, packageRoot: root, declaration: undefined,
        takeOver: false, otherPackagePaths: [], passthrough: args.passthrough,
        piSubcommand: args.piSubcommand, homedir: homedir(), baseEnv: {
          ...process.env, GENTLE_PI_CONFIG_HOME: join(state, 'gentle-ai'),
          GENTLE_SHELL_USER_PI_HOME: agent, ENGRAM_BIN: '/usr/local/bin/engram', ENGRAM_URL: '',
          // Upstream prompt history hardcodes ~/.pi; disable capture, never patch upstream.
          GENTLE_PI_HISTORY_CAPTURE: '0', GENTLE_SHELL_NO_AUTO_SETUP: '1',
          GENTLE_PI_SKIP_GENTLE_AI_INSTALL: '1',
        } });
      const child = spawn(invocation.command, invocation.args, { stdio: 'inherit', env: invocation.env });
      const handlers = ['SIGINT', 'SIGTERM', 'SIGHUP'].map(signal => {
        const handler = () => child.kill(signal);
        process.on(signal, handler);
        return [signal, handler];
      });
      child.on('error', error => { console.error(`Gentle Shell: ${error.message}`); process.exitCode = 1; });
      child.on('close', (code, signal) => {
        for (const [name, handler] of handlers) process.removeListener(name, handler);
        process.exitCode = signal ? 128 + ({ SIGINT: 2, SIGTERM: 15, SIGHUP: 1 }[signal] ?? 1) : (code ?? 1);
      });
  }
} catch (error) {
  console.error(`Gentle Shell: ${error.message}.`);
  process.exitCode = 1;
}
