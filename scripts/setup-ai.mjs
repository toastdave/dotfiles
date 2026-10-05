#!/usr/bin/env node
// Restore only declared skills and instructions; never copy authentication or app state.
import { readFileSync, existsSync, lstatSync, realpathSync, mkdirSync, renameSync,
  symlinkSync, readlinkSync, readdirSync, cpSync } from 'node:fs';
import { dirname, join, resolve, relative } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const home = homedir();
const manifest = JSON.parse(readFileSync(join(root, 'ai/skills.json'), 'utf8'));
const args = new Set(process.argv.slice(2));
const valid = ['--link-existing', '--vendors-only', '--resume'];
if ([...args].some(x => !valid.includes(x))) {
  console.error(`Usage: node scripts/setup-ai.mjs [${valid.join(' | ')}]`);
  process.exit(2);
}
const run = (command, argv, options = {}) => execFileSync(command, argv, { stdio: 'inherit', ...options });
const backupRoot = join(home, '.local/state/dotfiles/backups', `${Date.now()}-${process.pid}`);
function present(path) { try { lstatSync(path); return true; } catch { return false; } }
function backup(path) {
  let destination = join(backupRoot, relative(home, path));
  while (present(destination)) destination += ".previous";
  mkdirSync(dirname(destination), { recursive: true });
  // A parent may have been a folded Stow link: resolve the source before moving.
  renameSync(path, destination);
  console.log(`Backed up ${path} -> ${destination}`);
}
function link(source, destination) {
  if (!existsSync(source)) throw new Error(`Missing source: ${source}`);
  if (present(destination)) {
    try { if (realpathSync(destination) === realpathSync(source)) return; } catch {}
    backup(destination);
  }
  mkdirSync(dirname(destination), { recursive: true });
  symlinkSync(relative(realpathSync(dirname(destination)), realpathSync(source)), destination);
}

try {
  const canonical = join(home, '.agents/skills');
  const targets = ['.claude/skills', '.codex/skills', '.config/opencode/skills', '.pi/agent/skills'];
  let personal;
  if (!args.has('--vendors-only')) {
    personal = process.env.PERSONAL_SKILLS_DIR || join(home, 'code/projects/skills');
    if (!existsSync(personal)) {
      mkdirSync(dirname(personal), { recursive: true });
      run('git', ['clone', manifest.personalRepository, personal]);
    }
    // Existing checkout is authoritative; never reset, pull over edits, or change branches.
    if (!existsSync(join(personal, 'install'))) throw new Error(`Not a personal-skills checkout: ${personal}`);
  }
  if (!args.has('--link-existing')) {
    for (const vendor of manifest.vendors) {
      if (args.has('--resume')) {
        const lockPath = join(home, '.agents/.skill-lock.json');
        const lock = existsSync(lockPath) ? JSON.parse(readFileSync(lockPath, 'utf8')).skills : {};
        if (vendor.skills.every(name => lock[name]?.source === vendor.source && lock[name]?.ref === vendor.ref && existsSync(join(canonical, name, 'SKILL.md')))) {
          console.log(`Already restored ${vendor.source}@${vendor.ref}`);
          continue;
        }
      }
      console.log(`\nRestore ${vendor.source}@${vendor.ref}`);
      run('npx', ['--yes', `skills@${manifest.skillsCliVersion}`, 'add',
        `https://github.com/${vendor.source}/tree/${vendor.ref}`, '--global',
        '--skill', ...vendor.skills, '--agent', 'codex', 'claude-code', 'opencode', '--yes']);
      const restored = JSON.parse(readFileSync(join(home, '.agents/.skill-lock.json'), 'utf8')).skills;
      for (const name of vendor.skills) {
        if (!existsSync(join(canonical, name, 'SKILL.md')) || restored[name]?.source !== vendor.source || restored[name]?.ref !== vendor.ref) {
          throw new Error(`Installer did not restore ${name} at ${vendor.source}@${vendor.ref}`);
        }
      }
    }
  } else {
    // Adopt older manual installs without fetching or changing skill contents.
    for (const vendor of manifest.vendors) for (const name of vendor.skills) {
      const destination = join(canonical, name);
      if (existsSync(join(destination, 'SKILL.md'))) continue;
      const source = targets.map(t => join(home, t, name)).find(p => existsSync(join(p, 'SKILL.md')));
      if (!source) throw new Error(`Missing ${name}; rerun without --link-existing to restore it`);
      if (present(destination)) backup(destination);
      mkdirSync(canonical, { recursive: true });
      cpSync(source, destination, { recursive: true, dereference: true });
    }
  }
  // Normalize supported clients to one source, preserving conflicting installed copies.
  for (const vendor of manifest.vendors) for (const name of vendor.skills) {
    for (const target of targets) link(join(canonical, name), join(home, target, name));
  }
  if (personal) {
    const names = readdirSync(join(personal, 'skills')).filter(name => existsSync(join(personal, 'skills', name, 'SKILL.md')));
    for (const name of names) {
      const source = join(personal, 'skills', name);
      for (const target of ['.agents/skills', ...targets]) link(source, join(home, target, name));
    }
    link(join(root, 'ai/.agents/AGENTS.md'), join(home, '.agents/AGENTS.md'));
    link(join(home, '.agents/AGENTS.md'), join(home, '.codex/AGENTS.md'));
    link(join(home, '.agents/AGENTS.md'), join(home, '.pi/agent/AGENTS.md'));
    link(join(root, 'ai/.claude/CLAUDE.md'), join(home, '.claude/CLAUDE.md'));
  }
  if (!args.has('--vendors-only')) {
    const pi = join(home, '.pi/agent');
    mkdirSync(pi, { recursive: true });
    for (const filename of ['settings.json', 'mcp.json']) {
      const destination = join(pi, filename);
      if (!present(destination)) cpSync(join(root, 'ai/pi', filename), destination);
    }
    // Existing preferences and credentials remain local; restore declared extensions.
    if (!args.has('--link-existing')) {
      const settings = JSON.parse(readFileSync(join(root, 'ai/pi/settings.json'), 'utf8'));
      for (const source of settings.packages) {
        const [name, version] = source.slice(4).split('@');
        const pkg = join(pi, 'npm/node_modules', name, 'package.json');
        const local = JSON.parse(readFileSync(join(pi, 'settings.json'), 'utf8'));
        if (existsSync(pkg) && JSON.parse(readFileSync(pkg, 'utf8')).version === version && local.packages?.includes(source)) continue;
        run('pi', ['install', source]);
      }
    }
  }
  // Remove only dead links into the shared skills directory. Preserve other client content.
  for (const target of targets) {
    const directory = join(home, target);
    if (!existsSync(directory)) continue;
    for (const name of readdirSync(directory)) {
      const path = join(directory, name);
      if (!lstatSync(path).isSymbolicLink() || existsSync(path)) continue;
      const oldSource = resolve(dirname(path), readlinkSync(path));
      if (oldSource.startsWith(`${canonical}/`) || (personal && oldSource.startsWith(`${resolve(personal, 'skills')}/`))) {
        // Backup is reversible, including retired names from previous vendor installs.
        backup(path);
      }
    }
  }
  console.log('\nAI skills restored. Authenticate each CLI and restore desktop plugins separately (see README).');
} catch (error) {
  console.error(`\nAI setup failed: ${error.message}`);
  process.exit(1);
}
