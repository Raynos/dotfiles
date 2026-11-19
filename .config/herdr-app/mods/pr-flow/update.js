// Tells you when a newer PR Flow release is out. At most once a day, one read-only
// `gh api repos/<REPO>/releases/latest` with your own login. Nothing is installed by the
// mod: it shows what changed and a prompt to hand your agent. Turn it off in settings.
export const REPO = 'jjangsky/herdr-pr-flow';
export const CHECK_EVERY_MS = 24 * 60 * 60 * 1000;

// a > b for versions like v1.2.3.
export function newer(a, b) {
  const parts = (v) => String(v ?? '').replace(/^v/, '').split('.').map((n) => parseInt(n, 10) || 0);
  const [x, y] = [parts(a), parts(b)];
  for (let i = 0; i < 3; i++) if ((x[i] ?? 0) !== (y[i] ?? 0)) return (x[i] ?? 0) > (y[i] ?? 0);
  return false;
}

// Whether it's time to ask GitHub again.
export function due(state, now) {
  return !state?.off && now - (state?.checked ?? 0) >= CHECK_EVERY_MS;
}

// The parts of GitHub's release we keep, or null for anything unexpected.
export function parseRelease(json, repo = REPO) {
  if (!json || typeof json.tag_name !== 'string' || json.draft || json.prerelease) return null;
  const url = String(json.html_url ?? '');
  return {
    tag: json.tag_name,
    notes: String(json.body ?? '').slice(0, 4000),
    url: url.startsWith(`https://github.com/${repo}/`) ? url : `https://github.com/${repo}/releases`,
  };
}

// The release to offer, or null: newer than this copy, not turned off, not put off with "Later".
export function offer(state, version) {
  const latest = state?.latest;
  if (state?.off || !latest || !newer(latest.tag, version) || state.dismissed === latest.tag) return null;
  return latest;
}

export function updatePrompt(lang) {
  return lang === 'ko'
    ? `github.com/${REPO} 최신 버전으로 pr-flow 모드를 업데이트해줘. 레포의 mods/pr-flow 를 ~/.config/herdr-app/mods/ 에 복사하고 herdr-app check 로 확인해줘.`
    : `Update the pr-flow mod from github.com/${REPO}: copy the repo's mods/pr-flow into ~/.config/herdr-app/mods/ and run herdr-app check.`;
}
