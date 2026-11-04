import { accessSync, constants, readFileSync, realpathSync, statSync } from 'node:fs';
import { join, delimiter } from 'node:path';
import { homedir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { TOML } from './config.mjs';

export const agents = {
  claude: { retired: 'npm:@anthropic-ai/claude-code', casks: ['claude-code', 'claude-code@latest'] },
  codex: { retired: 'npm:@openai/codex', casks: ['codex'] },
};
export function run(command, args, options = {}) {
  return execFileSync(command, args, { encoding: 'utf8', timeout: 120000, stdio: ['ignore', 'pipe', 'pipe'], ...options });
}
export function managementTasks(root) {
  const { tasks } = TOML.parse(readFileSync(join(root, 'mise.toml'), 'utf8'));
  return Object.fromEntries(Object.entries(tasks).map(([name, task]) => [name, { ...task, dir: root }]));
}
export function executable(name, env = process.env) {
  for (const directory of (env.PATH || '').split(delimiter)) {
    const candidate = join(directory || '.', name);
    try { accessSync(candidate, constants.X_OK); if (statSync(candidate).isFile()) return realpathSync(candidate); } catch { /* try next PATH entry */ }
  }
  throw new Error(`${name} is not executable on PATH`);
}
export function miseRun(args, options) {
  return run(executable('mise'), ['-C', homedir(), ...args], options);
}
export function installedCasks() {
  if (process.platform !== 'darwin') return new Set();
  return new Set(run('brew', ['list', '--cask']).trim().split(/\s+/).filter(Boolean));
}
export function agentOwnership({ omarchy = false } = {}) {
  const installed = JSON.parse(miseRun(['ls', '--json']));
  const casks = installedCasks();
  const problems = [];
  for (const [name, policy] of Object.entries(agents)) {
    const active = installed[name]?.find(tool => tool.active && tool.installed);
    if (!active) { problems.push(`${name}: declare and install the native mise tool; run mise run setup`); continue; }
    const expected = realpathSync(miseRun(['which', name]).trim());
    if (!expected.startsWith(`${realpathSync(active.install_path)}/`)) problems.push(`${name}: mise resolves outside its native installation`);
    const actual = executable(name);
    const dispatcher = omarchy && actual.startsWith(`${homedir()}/.local/bin/`) && readFileSync(actual, 'utf8').includes('omarchy-agent-account-exec');
    if (actual !== expected && !dispatcher) problems.push(`${name}: PATH is shadowed; open a new shell or run mise exec -- ${name}`);
    const duplicates = policy.casks.filter(cask => casks.has(cask));
    if (duplicates.length) problems.push(`${name}: duplicate Homebrew CLI cask(s): ${duplicates.join(', ')}; run mise run setup`);
  }
  if (process.env.DISABLE_AUTOUPDATER !== '1') problems.push('Claude self-updates are enabled; rerun setup and use mise to update agents');
  if (problems.length) throw new Error(problems.join('; '));
}
export function pathIsInUse(path, processList) {
  // A retained inactive install is safe; deleting an agent running another session is not.
  return processList.split('\n').some(line => line.includes(`${path}/`));
}
export function verifyAgents() {
  const installed = JSON.parse(miseRun(['ls', '--json']));
  for (const name of Object.keys(agents)) {
    const active = installed[name]?.find(tool => tool.active && tool.installed);
    if (!active) throw new Error(`Native mise ${name} is not active; refusing to remove other installations`);
    const binary = realpathSync(miseRun(['which', name]).trim());
    if (!binary.startsWith(`${realpathSync(active.install_path)}/`)) throw new Error(`${name} resolves outside its native mise installation; remove conflicting declarations before migration`);
    const output = run(binary, ['--version']).trim();
    if (!output.includes(active.version)) throw new Error(`${name} reports ${output}, expected ${active.version}; refusing cleanup`);
    console.log(`${name}: native mise ${active.version} verified`);
  }
  return installed;
}
export function migrateAgents() {
  // Verify BOTH replacements before removing either old installation.
  const installed = verifyAgents();
  const processes = run('ps', ['-axo', 'comm=']);
  const casks = installedCasks();
  const removals = [];
  for (const [name, policy] of Object.entries(agents)) {
    for (const old of installed[policy.retired] || []) {
      if (!old.installed) continue;
      if (old.active) throw new Error(`Remove ${policy.retired} from its mise declaration before migration`);
      if (pathIsInUse(old.install_path, processes)) {
        console.warn(`Retained running ${policy.retired}@${old.version}: ${old.install_path}. Rerun setup after that session exits.`);
        continue;
      }
      removals.push(() => miseRun(['uninstall', `${policy.retired}@${old.version}`], { stdio: 'inherit' }));
    }
    for (const cask of policy.casks.filter(cask => casks.has(cask))) {
      const path = run('brew', ['--caskroom', cask]).trim();
      if (pathIsInUse(path, processes)) throw new Error(`Close the Homebrew ${name} session at ${path}, then rerun setup; replacement is installed`);
      removals.push(() => run('brew', ['uninstall', '--cask', cask], { stdio: 'inherit' }));
    }
  }
  // Check every conflict before starting removals.
  for (const remove of removals) remove();
  miseRun(['reshim'], { stdio: 'inherit' });
}
