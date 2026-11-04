import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, rmSync, symlinkSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { managementTasks, pathIsInUse, executable } from '../scripts/lib/tooling.mjs';
import { TOML } from '../scripts/lib/config.mjs';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

test('native agents have a single declaration and Claude updates through mise', () => {
  const config = TOML.parse(readFileSync(join(root, 'mise/.config/mise/config.toml'), 'utf8'));
  assert.equal(config.tools.claude, 'latest');
  assert.equal(config.tools.codex, 'latest');
  assert.equal(config.env.DISABLE_AUTOUPDATER, '1');
  assert.equal('npm:@openai/codex' in config.tools, false);
  assert.equal('npm:@anthropic-ai/claude-code' in config.tools, false);
});

test('global tasks use their checkout even when called from another project', () => {
  const directory = mkdtempSync(join(tmpdir(), 'dotfiles-tasks-'));
  try {
    const config = join(directory, 'config.toml');
    writeFileSync(config, TOML.stringify({ tasks: managementTasks(root) }));
    const output = execFileSync(executable('mise'), ['-C', directory, 'run', 'setup', '--', '--help'], {
      encoding: 'utf8', timeout: 30000,
      env: { ...process.env, MISE_CONFIG_DIR: directory, MISE_GLOBAL_CONFIG_FILE: config, MISE_YES: '1' },
    });
    assert.match(output, /Usage:.*bootstrap.sh.*--headless.*--skip-ai.*--omarchy/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('ownership resolves symlinks and skips broken PATH entries', () => {
  const directory = mkdtempSync(join(tmpdir(), 'dotfiles-path-'));
  try {
    mkdirSync(join(directory, 'first')); mkdirSync(join(directory, 'second'));
    symlinkSync(join(directory, 'missing'), join(directory, 'first/agent'));
    symlinkSync(process.execPath, join(directory, 'second/agent'));
    assert.equal(executable('agent', { PATH: `${directory}/first:${directory}/second` }), executable('node', { PATH: dirname(process.execPath) }));
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('migration retains an executing version without confusing adjacent version paths', () => {
  const path = '/home/dev/.local/share/mise/installs/npm-openai-codex/1.2.3';
  assert.equal(pathIsInUse(path, `${path}/lib/vendor/bin/codex\n/usr/bin/node`), true);
  assert.equal(pathIsInUse(path, `${path}4/lib/vendor/bin/codex\n/usr/bin/node`), false);
});
