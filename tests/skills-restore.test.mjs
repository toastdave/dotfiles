import test from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync,
  rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { homedir, tmpdir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { execFileSync, spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const targets = ['.agents/skills', '.claude/skills', '.codex/skills', '.config/opencode/skills', '.pi/agent/skills'];

test('real skills CLI restores fresh homes, resumes XDG installs and preserves custom skills after vendor failure', { timeout: 180000 }, t => {
  const directory = mkdtempSync(join(tmpdir(), 'dotfiles-skills-restore-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const repo = join(directory, 'dotfiles');
  const put = (path, contents) => {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, contents);
  };
  for (const file of ['scripts/setup-ai.mjs', 'scripts/setup-omarchy.mjs', 'scripts/lib/skills.mjs', 'scripts/lib/config.mjs']) {
    mkdirSync(dirname(join(repo, file)), { recursive: true });
    cpSync(join(root, file), join(repo, file));
  }
  cpSync(join(root, 'ai'), join(repo, 'ai'), { recursive: true });
  symlinkSync(join(root, 'scripts/node_modules'), join(repo, 'scripts/node_modules'));
  const git = (cwd, ...args) => execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  const makeRepository = (name, skill) => {
    const source = join(directory, name);
    put(join(source, 'skills', skill, 'SKILL.md'), `---\nname: ${skill}\ndescription: Restore validation skill.\n---\nKeep this skill.\n`);
    put(join(source, 'install'), '#!/bin/sh\n');
    git(source, 'init', '-q');
    git(source, 'add', '.');
    git(source, '-c', 'user.name=Dotfiles validation', '-c', 'user.email=validation@example.test', 'commit', '-qm', 'test: add validation skill');
    return source;
  };
  const vendorRepo = makeRepository('vendor', 'vendor-example');
  const personal = makeRepository('personal', 'personal-example');
  const vendor = { source: 'dotfiles-validation/skills', ref: git(vendorRepo, 'rev-parse', 'HEAD'), skills: ['vendor-example'] };
  const manifest = { skillsCliVersion: JSON.parse(readFileSync(join(root, 'ai/skills.json'))).skillsCliVersion,
    personalRepository: personal, vendors: [vendor] };
  const saveManifest = () => put(join(repo, 'ai/skills.json'), JSON.stringify(manifest));
  saveManifest();
  // Install no Pi extensions in this transport/link test; the production pins stay unchanged.
  put(join(repo, 'ai/pi/settings.json'), '{"packages":[]}\n');
  const run = (home, xdg, ...args) => {
    const result = spawnSync(process.execPath, [join(repo, 'scripts/setup-ai.mjs'), '--merge', ...args], {
      cwd: repo, encoding: 'utf8', timeout: 90000, maxBuffer: 2 * 1024 * 1024,
      env: { ...process.env, HOME: home, XDG_STATE_HOME: xdg,
        XDG_CONFIG_HOME: join(home, '.config'), CODEX_HOME: join(home, '.codex'), CLAUDE_CONFIG_DIR: join(home, '.claude'),
        PERSONAL_SKILLS_DIR: '', GH_TOKEN: '', GITHUB_TOKEN: '', CI: '1', NO_COLOR: '1', DO_NOT_TRACK: '1',
        npm_config_cache: process.env.npm_config_cache || join(homedir(), '.npm'),
        // Use actual Git and the pinned public CLI against a tiny local Git source.
        // Only this source URL is redirected; no host Git configuration is modified.
        GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_COUNT: '2',
        GIT_CONFIG_KEY_0: `url.${pathToFileURL(vendorRepo).href}.insteadOf`, GIT_CONFIG_VALUE_0: 'https://github.com/dotfiles-validation/skills.git',
        GIT_CONFIG_KEY_1: 'protocol.file.allow', GIT_CONFIG_VALUE_1: 'always', SKILLS_CLONE_TIMEOUT_MS: '10000' },
    });
    assert.ifError(result.error);
    return { status: result.status, output: result.stdout + result.stderr };
  };
  const linked = (home, skill) => {
    const source = realpathSync(join(home, '.agents/skills', skill));
    for (const target of targets) assert.equal(realpathSync(join(home, target, skill)), source);
  };
  const home = join(directory, 'xdg-home');
  const state = join(home, '.local/state');
  let result = run(home, state);
  assert.equal(result.status, 0, result.output);
  const inventory = join(state, 'skills/.skill-lock.json');
  assert.equal(JSON.parse(readFileSync(inventory)).skills['vendor-example'].ref, vendor.ref);
  assert.equal(existsSync(join(home, '.agents/.skill-lock.json')), false);
  linked(home, 'vendor-example');
  linked(home, 'personal-example');
  result = run(home, state, '--resume');
  assert.equal(result.status, 0, result.output);
  assert.match(result.output, /Already restored dotfiles-validation\/skills/);
  // A later source failure must leave both custom skills and completed sources usable.
  const failingHome = join(directory, 'partial-home');
  manifest.vendors.push({ ...vendor, skills: ['nonexistent-example'] });
  saveManifest();
  result = run(failingHome, join(failingHome, 'state'));
  assert.notEqual(result.status, 0, result.output);
  assert.match(result.output, /AI setup failed/);
  linked(failingHome, 'personal-example');
  linked(failingHome, 'vendor-example');
  manifest.vendors.pop();
  saveManifest();
  const legacyHome = join(directory, 'legacy-home');
  result = run(legacyHome, '');
  assert.equal(result.status, 0, result.output);
  assert.equal(existsSync(join(legacyHome, '.agents/.skill-lock.json')), true);
  linked(legacyHome, 'vendor-example');
  linked(legacyHome, 'personal-example');
});
