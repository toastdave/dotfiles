#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { run } from './lib/tooling.mjs';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
try {
  const args = process.argv.slice(2);
  if (args.some(arg => arg !== '--dry-run') || args.length > 1) throw new Error('Usage: node scripts/update-brew.mjs [--dry-run]');
  if (process.platform !== 'darwin') throw new Error('Homebrew updates are only configured on macOS');
  // Only update declared packages that already exist; optional apps stay optional.
  for (const kind of ['brew', 'cask']) {
    const flag = kind === 'brew' ? '--formula' : '--cask';
    const installed = new Set(run('brew', ['list', flag]).trim().split(/\s+/));
    const declared = [...new Set(['Brewfile.core', 'Brewfile'].flatMap(file =>
      [...readFileSync(join(root, 'macos', file), 'utf8').matchAll(new RegExp(`^${kind} "([^"]+)"`, 'gm'))].map(match => match[1])))];
    const packages = declared.filter(name => installed.has(name) || installed.has(name.split('/').at(-1)));
    if (packages.length) {
      if (args.includes('--dry-run')) console.log(['brew', 'upgrade', flag, ...packages].join(' '));
      else run('brew', ['upgrade', flag, ...packages], { stdio: 'inherit', timeout: 0 });
    }
  }
} catch (error) { console.error(error.message); process.exitCode = 1; }
