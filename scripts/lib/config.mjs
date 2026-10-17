import { existsSync, readFileSync, mkdirSync, copyFileSync, realpathSync,
  statSync, lstatSync, writeFileSync, renameSync, unlinkSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { homedir } from 'node:os';
import { parse, modify, applyEdits, printParseErrorCode } from 'jsonc-parser';
import TOML from '@iarna/toml';

export { TOML };
export const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
export function parseTomlConfig(path, text) {
  try { return TOML.parse(text); }
  catch (error) {
    // Client TOML may contain credentials; never print the parser's source excerpt.
    throw new Error(`Invalid TOML in ${path} at line ${(error.line ?? 0) + 1}, column ${(error.col ?? 0) + 1}`);
  }
}
export function readJson(path, text = existsSync(path) ? readFileSync(path, 'utf8') : '{}\n') {
  const errors = [];
  const value = parse(text, errors, { allowTrailingComma: true });
  if (errors.length || !object(value)) {
    throw new Error(`Invalid JSON/JSONC object in ${path}: ${errors.map(e => printParseErrorCode(e.error)).join(', ')}`);
  }
  return { text, value };
}

export const packageSource = entry => typeof entry === 'string' ? entry : entry?.source;
export function packageIdentity(entry) {
  const source = packageSource(entry);
  if (typeof source !== 'string') throw new Error('Pi packages must be source strings or objects with a source');
  return source.match(/^(npm:(?:@[^/]+\/)?[^@]+)(?:@.*)?$/)?.[1] || source;
}
export function mergePackages(local, declared) {
  if (!Array.isArray(local)) throw new Error('Pi settings.packages must be an array');
  const wanted = new Map(declared.map(p => [packageIdentity(p), p]));
  const seen = new Set();
  const result = [];
  for (const entry of local) {
    const id = packageIdentity(entry);
    if (seen.has(id) && wanted.has(id)) continue;
    seen.add(id);
    result.push(wanted.has(id)
      ? (object(entry) ? { ...entry, source: packageSource(wanted.get(id)) } : wanted.get(id))
      : entry);
  }
  for (const [id, entry] of wanted) if (!seen.has(id)) result.push(entry);
  return result;
}

// Plan every edit before writing; malformed existing config aborts without partial edits.
// Writes retain symlinks, original permissions, comments and unrelated configuration.
export class ConfigPlan {
  constructor(home = homedir()) {
    this.home = home;
    this.files = new Map();
    this.backups = join(home, '.local/state/dotfiles/backups', `${Date.now()}-${process.pid}`);
  }
  text(path) { return this.files.get(path) ?? this.textOnDisk(path) ?? ''; }
  set(path, text) { this.files.set(path, text); }
  json(path, defaults, { packages = false, entries = [] } = {}) {
    const original = this.text(path);
    let { text, value } = readJson(path, original || '{}\n');
    const put = (keys, data) => {
      text = applyEdits(text, modify(text, keys, data, { formattingOptions: { insertSpaces: true, tabSize: 2, eol: '\n' } }));
    };
    const merge = (current, additions, keys = []) => {
      for (const [key, wanted] of Object.entries(additions)) {
        if (packages && keys.length === 0 && key === 'packages') {
          const merged = mergePackages(current[key] ?? [], wanted);
          if (JSON.stringify(merged) !== JSON.stringify(current[key])) put([key], merged);
        } else if (!(key in current)) put([...keys, key], wanted);
        else if (keys.length === 1 && entries.includes(keys[0])) continue;
        else if (object(wanted)) {
          if (!object(current[key])) throw new Error(`Expected an object at ${path}: ${[...keys, key].join('.')}`);
          merge(current[key], wanted, [...keys, key]);
        }
      }
    };
    merge(value, defaults);
    readJson(path, text);
    // Clients such as Claude rewrite their JSON without a trailing newline.
    // A semantically complete config needs no formatting-only reconciliation.
    this.set(path, text === original || text.endsWith('\n') ? text : `${text}\n`);
  }
  block(path, name, content) {
    const start = `# >>> dotfiles ${name} >>>`;
    const end = `# <<< dotfiles ${name} <<<`;
    const old = this.text(path);
    const first = old.indexOf(start);
    const last = old.indexOf(end);
    if ((first < 0) !== (last < 0) || (first >= 0 && (last < first || old.indexOf(start, first + start.length) >= 0))) {
      throw new Error(`Malformed managed block in ${path}`);
    }
    const block = `${start}\n${content.trimEnd()}\n${end}`;
    this.set(path, first < 0
      ? `${old}${old && !old.endsWith('\n') ? '\n' : ''}${old ? '\n' : ''}${block}\n`
      : `${old.slice(0, first)}${block}${old.slice(last + end.length)}`);
  }
  tomlMcp(path, servers) {
    let text = this.text(path);
    const existing = parseTomlConfig(path, text);
    if (existing.mcp_servers !== undefined && !object(existing.mcp_servers)) throw new Error(`Invalid mcp_servers in ${path}`);
    for (const [name, config] of Object.entries(servers)) {
      if (existing.mcp_servers && name in existing.mcp_servers) continue;
      text += `${text.endsWith('\n') || !text ? '' : '\n'}\n${TOML.stringify({ mcp_servers: { [name]: config } })}`;
    }
    parseTomlConfig(path, text);
    this.set(path, text);
  }
  apply({ check = false } = {}) {
    const changed = [...this.files].filter(([path, text]) => this.textOnDisk(path) !== text);
    if (check && changed.length) throw new Error(`Rerun setup to reconcile: ${changed.map(([path]) => path).join(', ')}`);
    for (const [path, text] of check ? [] : changed) {
      const target = existsSync(path) ? realpathSync(path) : path;
      mkdirSync(dirname(target), { recursive: true });
      const mode = existsSync(path) ? statSync(path).mode & 0o777 : 0o600;
      if (existsSync(path)) {
        const rel = relative(this.home, path);
        const backup = join(this.backups, rel.startsWith('..') ? join('_external', path.replace(/^\/+/, '')) : rel);
        mkdirSync(dirname(backup), { recursive: true, mode: 0o700 });
        copyFileSync(path, backup);
      }
      const temp = `${target}.dotfiles-${process.pid}.tmp`;
      try {
        writeFileSync(temp, text, { mode, flag: 'wx' });
        renameSync(temp, target);
      } finally { if (existsSync(temp)) unlinkSync(temp); }
      console.log(`Updated ${path}`);
    }
    return changed.map(([path]) => path);
  }
  textOnDisk(path) {
    if (!existsSync(path) && lstatSync(path, { throwIfNoEntry: false })?.isSymbolicLink()) {
      throw new Error(`Repair the dangling configuration symlink before setup: ${path}`);
    }
    return existsSync(path) ? readFileSync(path, 'utf8') : undefined;
  }
}
