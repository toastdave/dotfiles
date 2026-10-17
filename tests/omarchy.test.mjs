import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, existsSync, rmSync,
  symlinkSync, lstatSync, chmodSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { ConfigPlan, TOML, readJson, mergePackages } from '../scripts/lib/config.mjs';
import { configuration, root, toolDefaults } from '../scripts/setup-omarchy.mjs';

function fixture(t) {
  const home = mkdtempSync(join(tmpdir(), 'dotfiles-omarchy-'));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const put = (name, content) => { const p = join(home, name); mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, content); return p; };
  return { home, put, read: name => readFileSync(join(home, name), 'utf8') };
}

test('existing Omarchy desktop, Bash, credentials, client preferences and MCPs survive setup and rerun', t => {
  const { home, put, read } = fixture(t);
  const untouched = {
    '.config/mise/config.toml': '[tools]\nnode = "26"\nruby = "3"\n',
    '.config/ghostty/config': 'config-file = theme.conf\n',
    '.config/tmux/tmux.conf': 'set -g prefix C-Space\n',
    '.config/hypr/hyprland.lua': '-- existing desktop\n',
    '.local/bin/codex': '#!/bin/bash\nexec omarchy-agent-account-exec codex "$@"\n',
    '.pi/agent/auth.json': '{"local-auth":"retain"}\n',
    '.codex/auth.json': '{"local-auth":"retain"}\n',
  };
  for (const [name, content] of Object.entries(untouched)) put(name, content);
  put('.bashrc', '# Omarchy startup\nexport OMARCHY_SENTINEL=retained\nalias gw="echo existing"\n');
  put('.agents/AGENTS.md', 'Keep my Omarchy instructions.\n');
  put('.codex/AGENTS.md', 'Keep my Codex instructions.\n');
  put('.claude/CLAUDE.md', 'Keep my Claude instructions.\n');
  put('.pi/agent/AGENTS.md', 'Keep my Pi instructions.\n');
  put('.codex/config.toml', '# retain comment\nmodel = "my-model"\n[mcp_servers.personal]\ncommand = "personal"\n');
  put('.claude.json', '{\n  // keep this comment\n  "mcpServers": {"personal": {"command":"personal"}},\n  "private": "retain",\n}\n');
  put('.config/opencode/opencode.jsonc', '{\n  // keep theme integration\n  "theme": "omarchy",\n  "mcp": {"personal":{"type":"remote","url":"https://example.test"}},\n}\n');
  put('.pi/agent/settings.json', '{"theme":"omarchy","defaultModel":"my-model","packages":["npm:extra@1","npm:pi-web-access@0.1.0"]}\n');
  configuration(home).apply();
  const snapshot = new Map([...configuration(home).files.keys()].map(p => [p, readFileSync(p, 'utf8')]));
  assert.deepEqual(configuration(home).apply(), []);
  configuration(home).apply({ check: true });
  for (const [p, content] of snapshot) assert.equal(readFileSync(p, 'utf8'), content);
  for (const [name, content] of Object.entries(untouched)) assert.equal(read(name), content, name);
  assert.ok(read('.agents/AGENTS.md').startsWith('Keep my Omarchy instructions.'));
  assert.ok(read('.codex/AGENTS.md').startsWith('Keep my Codex instructions.'));
  assert.ok(read('.claude/CLAUDE.md').startsWith('Keep my Claude instructions.'));
  assert.ok(read('.pi/agent/AGENTS.md').startsWith('Keep my Pi instructions.'));
  const codex = TOML.parse(read('.codex/config.toml'));
  assert.equal(codex.model, 'my-model');
  assert.equal(codex.mcp_servers.personal.command, 'personal');
  assert.equal(codex.mcp_servers.railway.command, 'railway');
  assert.ok(read('.codex/config.toml').startsWith('# retain comment'));
  const claude = readJson(join(home, '.claude.json')).value;
  assert.equal(claude.private, 'retain');
  assert.equal(claude.mcpServers.personal.command, 'personal');
  assert.equal(claude.mcpServers.railway.type, 'stdio');
  assert.ok(read('.claude.json').includes('// keep this comment'));
  const oc = readJson(join(home, '.config/opencode/opencode.jsonc')).value;
  assert.equal(oc.theme, 'omarchy');
  assert.deepEqual(oc.mcp.railway.command, ['railway', 'mcp']);
  assert.ok(read('.config/opencode/opencode.jsonc').includes('// keep theme integration'));
  assert.equal(existsSync(join(home, '.config/opencode/opencode.json')), false);
  const pi = readJson(join(home, '.pi/agent/settings.json')).value;
  assert.equal(pi.theme, 'omarchy');
  assert.equal(pi.defaultModel, 'my-model');
  assert.ok(pi.packages.includes('npm:extra@1'));
  assert.ok(pi.packages.includes('npm:pi-web-access@0.14.0'));
  const shell = execFileSync('bash', ['--noprofile', '--norc', '-c', 'source "$HOME/.bashrc"; source "$HOME/.bashrc"; alias gw; printf "%s" "$OMARCHY_SENTINEL"'], { env: { ...process.env, HOME: home }, encoding: 'utf8' });
  assert.match(shell, /echo existing/);
  assert.match(shell, /retained$/);
  assert.equal(read('.bashrc').split('# >>> dotfiles omarchy >>>').length, 2);
});

test('invalid JSONC or managed blocks abort all planned changes', t => {
  const { home, put, read } = fixture(t);
  put('.bashrc', 'keep bash\n');
  put('.config/opencode/opencode.json', '{broken');
  assert.throws(() => configuration(home).apply(), /Invalid JSON/);
  assert.equal(read('.bashrc'), 'keep bash\n');
  assert.equal(existsSync(join(home, '.config/mise/conf.d/10-dotfiles.toml')), false);
  put('.config/opencode/opencode.json', '{}');
  put('.bashrc', '# >>> dotfiles omarchy >>>\nmissing end\n');
  assert.throws(() => configuration(home).apply(), /Malformed managed block/);
  assert.equal(existsSync(join(home, '.claude.json')), false);
});

test('a dangling config symlink is reported without replacing it', t => {
  const { home } = fixture(t);
  symlinkSync(join(home, 'missing'), join(home, '.bashrc'));
  assert.throws(() => configuration(home).apply(), /dangling configuration symlink/);
  assert.equal(lstatSync(join(home, '.bashrc')).isSymbolicLink(), true);
  assert.equal(existsSync(join(home,'.codex/config.toml')), false);
});

test('malformed credential-bearing TOML reports its location without exposing content', t => {
  const { home, put } = fixture(t);
  put('.codex/config.toml', 'private_key = DO_NOT_PRINT_THIS\n');
  assert.throws(() => configuration(home).apply(), error => {
    assert.match(error.message, /Invalid TOML.*config.toml.*line/);
    assert.equal(error.message.includes('DO_NOT_PRINT_THIS'), false);
    return true;
  });
  assert.equal(existsSync(join(home,'.config/mise/conf.d/10-dotfiles.toml')), false);
});

test('symlinks, permissions, backups and existing named MCP overrides are retained', t => {
  const { home, put, read } = fixture(t);
  const source = put('private/claude.json', '{"mcpServers":{"railway":{"type":"http","url":"https://example.test"}}}\n');
  chmodSync(source, 0o600);
  symlinkSync(source, join(home, '.claude.json'));
  const plan = configuration(home);
  plan.apply();
  assert.equal(lstatSync(join(home, '.claude.json')).isSymbolicLink(), true);
  assert.equal(statSync(source).mode & 0o777, 0o600);
  assert.equal(readJson(source).value.mcpServers.railway.type, 'http');
  // A no-op override doesn't rewrite or back up the credential-bearing source.
  assert.equal(read('private/claude.json'), '{"mcpServers":{"railway":{"type":"http","url":"https://example.test"}}}\n');
  const next = new ConfigPlan(home);
  next.json(join(home,'.claude.json'), { another: true });
  next.apply();
  assert.equal(readFileSync(join(next.backups,'.claude.json'),'utf8'), '{"mcpServers":{"railway":{"type":"http","url":"https://example.test"}}}\n');
});

test('Pi package options and unrelated sources survive replacing a declared extension pin', () => {
  assert.deepEqual(mergePackages([
    { source: 'npm:@org/extension@1', extensions: ['chosen.ts'] },
    'npm:@org/extension', 'git:example.test/my-extension',
  ], ['npm:@org/extension@2']), [
    { source: 'npm:@org/extension@2', extensions: ['chosen.ts'] }, 'git:example.test/my-extension',
  ]);
});

test('client formatting without a trailing newline stays a configuration no-op', t => {
  const { home, put, read } = fixture(t);
  configuration(home).apply();
  const client = JSON.stringify(readJson(join(home, '.claude.json')).value, null, 2);
  put('.claude.json', client);
  assert.deepEqual(configuration(home).apply(), []);
  configuration(home).apply({ check: true });
  assert.equal(read('.claude.json'), client);
  put('.config/mise/conf.d/10-dotfiles.toml', TOML.stringify({ tools: toolDefaults() }).trimEnd());
  assert.deepEqual(configuration(home).apply(), []);
  configuration(home).apply({ check: true });
});

test('a new Pi setup follows the generated Omarchy theme while an existing custom theme survives', t => {
  const { home, put } = fixture(t);
  const theme = '{"name":"omarchy-system","colors":{}}\n';
  put('.local/state/omarchy/current/theme/pi.json', theme);
  configuration(home).apply();
  assert.equal(readJson(join(home,'.pi/agent/settings.json')).value.theme,'omarchy-system');
  assert.equal(readFileSync(join(home,'.pi/agent/themes/omarchy-system.json'),'utf8'),theme);
  put('.pi/agent/settings.json','{"theme":"my-custom-theme"}\n');
  configuration(home).apply();
  assert.equal(readJson(join(home,'.pi/agent/settings.json')).value.theme,'my-custom-theme');
  configuration(home).apply({check:true});
});

test('profile inherits canonical tool versions and uses Omarchy agent names', () => {
  const canonical = TOML.parse(readFileSync(join(root,'mise/.config/mise/config.toml'),'utf8')).tools;
  const tools = toolDefaults();
  assert.deepEqual(tools.codex, canonical['npm:@openai/codex']);
  assert.deepEqual(tools.pi, { ...canonical['npm:@earendil-works/pi-coding-agent'], version: 'latest' });
  assert.equal(tools.claude, 'latest');
  assert.equal(tools.railway, 'latest');
  assert.equal('npm:@openai/codex' in tools, false);
  for (const [key, value] of Object.entries(canonical)) {
    if (!['npm:@openai/codex','npm:@earendil-works/pi-coding-agent'].includes(key)) assert.deepEqual(tools[key],value);
  }
});
