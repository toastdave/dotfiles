#!/usr/bin/env node
import { existsSync, readdirSync, lstatSync, realpathSync, readFileSync, accessSync, constants } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { homedir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const home = homedir();
const args = new Set(process.argv.slice(2));
if ([...args].some(arg => !['--omarchy', '--skip-ai'].includes(arg))) {
  console.error('Usage: node scripts/doctor.mjs [--omarchy] [--skip-ai]');
  process.exit(2);
}
const omarchy = args.has('--omarchy') || (existsSync(join(home,'.bashrc')) && readFileSync(join(home,'.bashrc'),'utf8').includes('# >>> dotfiles omarchy >>>'));
let failures = 0;
function check(label, task) {
  try { task(); console.log(`ok   ${label}`); }
  catch (e) { failures++; console.error(`FAIL ${label}: ${e.message}`); }
}
const run = (cmd, args) => execFileSync(cmd, args, { encoding: 'utf8', timeout: 60000, stdio: ['ignore','pipe','pipe'] });
for (const [name, commandArgs] of Object.entries({ mise: ['--version'],
  ...(omarchy ? { bash: ['--version'], railway: ['--version'], 'agent-browser': ['--version'] } : { stow: ['--version'], zsh: ['--version'] }),
  git: ['--version'], gh: ['--version'], tmux: ['-V'], bun: ['--version'], node: ['--version'],
  pnpm: ['--version'], python: ['--version'], rg: ['--version'], fd: ['--version'], btop: ['--version'],
  delta: ['--version'], codex: ['--version'], claude: ['--version'], opencode: ['--version'], pi: ['--version'] })) {
  check(name, () => run(name, commandArgs));
}
check('mise declarations installed', () => {
  const missing = run('mise', ['ls', '--missing', '--json']).trim();
  if (missing && Object.keys(JSON.parse(missing)).length) throw new Error(missing);
});
if (omarchy) {
  const { configuration } = await import('./setup-omarchy.mjs');
  check('Omarchy additive configuration', () => configuration().apply({ check: true }));
  check('agent-browser executable', () => {
    const config = JSON.parse(readFileSync(join(home,'.agent-browser/config.json'),'utf8'));
    accessSync(config.executablePath, constants.X_OK);
  });
} else for (const [target, source] of Object.entries({ '.zshrc': 'zsh/.zshrc', '.zprofile': 'zsh/.zprofile',
  '.config/mise/config.toml': 'mise/.config/mise/config.toml',
  ...(!args.has('--skip-ai') ? { '.agents/AGENTS.md': 'ai/.agents/AGENTS.md', '.pi/agent/AGENTS.md': 'ai/.agents/AGENTS.md',
    '.codex/AGENTS.md': 'ai/.agents/AGENTS.md', '.claude/CLAUDE.md': 'ai/.claude/CLAUDE.md' } : {}) })) {
  check(target, () => { if (realpathSync(join(home,target)) !== realpathSync(join(root,source))) throw new Error('not linked to canonical dotfiles'); });
}
if (!args.has('--skip-ai')) {
  for (const name of ['.agents/skills','.codex/skills','.claude/skills','.config/opencode/skills','.pi/agent/skills']) {
    check(`${name} links`, () => {
      const directory = join(home,name);
      const broken = readdirSync(directory).filter(n => lstatSync(join(directory,n)).isSymbolicLink() && !existsSync(join(directory,n)));
      if (broken.length) throw new Error(broken.join(', '));
    });
  }
  const manifest = JSON.parse(readFileSync(join(root,'ai/skills.json'),'utf8'));
  for (const v of manifest.vendors) for (const skill of v.skills) {
    check(`skill ${skill}`, () => {
      if (!existsSync(join(home,'.agents/skills',skill,'SKILL.md'))) throw new Error('missing; run setup-ai.mjs');
      for (const target of ['.claude/skills','.codex/skills','.config/opencode/skills','.pi/agent/skills']) {
        if (realpathSync(join(home,target,skill)) !== realpathSync(join(home,'.agents/skills',skill))) throw new Error(`${target} has a separate copy`);
      }
    });
  }
  const personal = process.env.PERSONAL_SKILLS_DIR || join(home, 'code/projects/skills');
  check('personal skill checkout', () => {
    if (!existsSync(join(personal, 'install'))) throw new Error('missing personal-skills checkout');
    for (const name of readdirSync(join(personal, 'skills'))) {
      const source = join(personal, 'skills', name);
      if (!existsSync(join(source, 'SKILL.md'))) continue;
      for (const target of ['.agents/skills','.claude/skills','.codex/skills','.config/opencode/skills','.pi/agent/skills']) {
        if (realpathSync(join(home,target,name)) !== realpathSync(source)) throw new Error(`${target}/${name} is not canonical`);
      }
    }
  });
  const piSettings = JSON.parse(readFileSync(join(root, 'ai/pi/settings.json'),'utf8'));
  for (const source of piSettings.packages) {
    const [, name, version] = source.match(/^npm:(.+)@([^@]+)$/);
    check(`Pi extension ${name}`, () => {
      const pkg = JSON.parse(readFileSync(join(home,'.pi/agent/npm/node_modules',name,'package.json'),'utf8'));
      if (pkg.version !== version) throw new Error(`expected ${version}, installed ${pkg.version}`);
    });
  }
}
console.log(`\n${failures} failed check(s). Authentication, desktop plugins, and SDK builds need separate validation.`);
process.exitCode = failures ? 1 : 0;
