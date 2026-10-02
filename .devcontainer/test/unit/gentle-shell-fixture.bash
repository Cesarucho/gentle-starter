# Hermetic package/release artifacts shared by installer and updater checks.
write_shell_fixture() {
	SHELL_PACKAGE="${TEST_ROOT}/shell.tgz"
	SHELL_ARCHIVE="${TEST_ROOT}/shell-private.tar.gz"
	SHELL_SOURCE="${TEST_ROOT}/shell-package"
	mkdir -p "${SHELL_SOURCE}/scripts" "${SHELL_SOURCE}/runtime" "${SHELL_SOURCE}/bin"
	printf 'fixture private binary\n' >"${TEST_ROOT}/gentle-ai"
	tar -czf "${SHELL_ARCHIVE}" -C "${TEST_ROOT}" gentle-ai
	SHELL_ARCHIVE_SHA="$(sha256sum "${SHELL_ARCHIVE}" | cut -d' ' -f1)"
	SHELL_BINARY_SHA="$(sha256sum "${TEST_ROOT}/gentle-ai" | cut -d' ' -f1)"
	printf '%s\n' '{"name":"gentle-pi","version":"4.0.0","type":"module","bin":{"gentle-shell":"bin/gentle-shell.mjs"},"engines":{"node":">=22.19.0"},"peerDependencies":{"@earendil-works/pi-coding-agent":">=0.99.1"}}' >"${SHELL_SOURCE}/package.json"
	cat >"${SHELL_SOURCE}/scripts/gentle-ai-installer.mjs" <<EOF
export const INSTALLER_VERSION='4.0.0';
export function resolveGentleAiReleaseAsset(platform, arch) {
  if(platform !== 'linux') throw Error('platform');
  arch=arch==='x64'?'amd64':arch;
  const name='gentle-ai_4.0.0_linux_'+arch+'.tar.gz';
  return {name, executable:'gentle-ai',sha256:'${SHELL_ARCHIVE_SHA}',binarySha256:'${SHELL_BINARY_SHA}',url:'https://github.com/Gentleman-Programming/gentle-ai/releases/download/v4.0.0/'+name};
}
EOF
	cat >"${SHELL_SOURCE}/runtime/gentle-ai-binary.mjs" <<'EOF'
import {readFileSync,lstatSync} from 'node:fs';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {homedir} from 'node:os';
import {resolveGentleAiReleaseAsset} from '../scripts/gentle-ai-installer.mjs';
export function gentleAiDevBinaryRegistrationPath() {return join(process.env.GENTLE_PI_CONFIG_HOME??join(homedir(),'.pi/gentle-ai'),'dev-binary.json');}
export function resolveGentleAiBinary(root,platform,readBinary,environment) {
  if(platform!=='linux'||Object.keys(environment.env).length||!environment.home.endsWith('.unused-verification-home')) throw Error('resolver environment contract');
  const dir=join(root,'.gentle-ai/v4.0.0'),binary=join(dir,'gentle-ai');
  for(const path of [join(root,'.gentle-ai'),dir,binary,join(dir,'integrity.json')]) if(lstatSync(path).isSymbolicLink()) throw Error('symlink');
  const asset=resolveGentleAiReleaseAsset(platform,process.arch);
  const manifest={version:'4.0.0',asset:asset.name,assetSha256:asset.sha256,binarySha256:asset.binarySha256};
  if(readFileSync(join(dir,'integrity.json'),'utf8')!==JSON.stringify(manifest)+'\n'||createHash('sha256').update(readBinary(binary)).digest('hex')!==asset.binarySha256) throw Error('integrity');
  return binary;
}
EOF
	printf '%s\n' 'console.log("native fixture",JSON.stringify(process.argv.slice(2)),process.env.GENTLE_SHELL_NO_AUTO_SETUP,process.env.GENTLE_PI_SKIP_GENTLE_AI_INSTALL);' >"${SHELL_SOURCE}/bin/gentle-shell.mjs"
	cat >"${SHELL_SOURCE}/runtime/gentle-shell-launcher.mjs" <<'EOF'
export function parseLauncherArgs(argv) {
  const args=argv.slice(0, argv.indexOf('--') < 0 ? argv.length : argv.indexOf('--'));
  return {packageRoot:args.find(arg=>arg==='--package-root'||arg.startsWith('--package-root=')),
    link:args.includes('--link'), home:args.find(arg=>arg.startsWith('--home='))?.slice(7),
    help:args.includes('--help'),version:args.includes('--version'),
    command:['setup','home'].includes(args[0])?args[0]:undefined,commandArgs:args.slice(1),
    passthrough:argv.slice(argv.indexOf('--')+1)};
}
export function findGentlePiDeclaration() {return undefined;}
export function describeVersion(input) {return 'gentle-shell '+input.gentlePiVersion+'\npi '+input.piVersion;}
export function checkPiVersion(text) {const version=text.trim();return {ok:/^\d+\.\d+\.\d+$/.test(version),version};}
export function buildPiInvocation(input) {return {command:input.runtime.command,args:[...input.runtime.args,'-e',input.packageRoot,...input.passthrough],env:{...input.baseEnv,PI_CODING_AGENT_DIR:input.home.dir,GENTLE_PI_AGENT_HOME:input.home.dir}};}
EOF
	mkdir -p "${TEST_ROOT}/pack/package"
	cp -a "${SHELL_SOURCE}/." "${TEST_ROOT}/pack/package/"
	tar -czf "${SHELL_PACKAGE}" -C "${TEST_ROOT}/pack" package
	SHELL_INTEGRITY="sha512-$(openssl dgst -sha512 -binary "${SHELL_PACKAGE}" | openssl base64 -A)"
	export SHELL_PACKAGE SHELL_ARCHIVE SHELL_SOURCE SHELL_ARCHIVE_SHA SHELL_BINARY_SHA SHELL_INTEGRITY
}
