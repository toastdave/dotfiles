import { join } from 'node:path';
import { homedir } from 'node:os';

// Match the pinned skills CLI's getSkillLockPath(), including its XDG override.
export function skillLockPath(home = homedir(), env = process.env) {
  return env.XDG_STATE_HOME
    ? join(env.XDG_STATE_HOME, 'skills', '.skill-lock.json')
    : join(home, '.agents', '.skill-lock.json');
}
