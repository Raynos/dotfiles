// Everything from GitHub is untrusted. Native text can't run escape codes, but they would
// show up as junk in logs, and bidi controls can reorder what a title appears to say.
const ANSI = /\u001b(?:\[[0-?]*[ -/]*[@-~]|\][^\u0007\u001b]*(?:\u0007|\u001b\\)|[@-Z\\-_])/g;
const CONTROL = /[\u0000-\u0008\u000b-\u001f\u007f-\u009f]/g;
const BIDI = /[‪-‮⁦-⁩]/g;

export function sanitize(value) {
  return String(value ?? '')
    .replace(ANSI, '')
    .replace(/\r\n?/g, '\n')
    .replace(CONTROL, '')
    .replace(BIDI, '')
    .replace(/\t/g, '    ');
}

export function parseDuration(value, fallbackMs) {
  if (typeof value === 'number' && Number.isFinite(value)) return value * 1000;
  const match = /^(\d+)\s*(ms|s|m|h)?$/.exec(String(value ?? '').trim());
  if (!match) return fallbackMs;
  return Number(match[1]) * { ms: 1, s: 1000, m: 60_000, h: 3_600_000 }[match[2] ?? 's'];
}
