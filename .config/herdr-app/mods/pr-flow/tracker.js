// Finds PRs from live agents and keeps their data fresh. It only reads. Everything it touches
// is passed in, so the loop runs against fakes in tests and has no timers of its own.
import { parsePrUrl } from './gh.js';
import { prState } from './status.js';
import { sanitize } from './text.js';
import { flowActive } from './flow.js';

const DISCOVER_WORKING_MS = 30_000;
const DISCOVER_IDLE_MS = 120_000;
const REMOTE_TTL_MS = 60_000;
const SETTLED_FACTOR = 4;
const MERGED_KEEP_MS = 24 * 3_600_000;
const CONCURRENCY = 4;
const FLOW_POLL_MS = 15_000;
const MINE_MS = 5 * 60_000;

function clean(pr) {
  return { ...pr, title: sanitize(pr.title), body: sanitize(pr.body) };
}

export function createTracker({ gh, remoteOf, worktreesOf = async () => [], store, settings, now = Date.now }) {
  const tracked = store.load();
  const live = new Map(); // url -> { pr, threads, issues, fetchedAt, error }
  const flows = new Map(); // url -> { runs, jobs: { runId: { jobs, final } }, checkedAt }
  const discovered = new Map(); // repo:branch -> at
  const previous = new Map(); // address -> status
  const remotes = new Map(); // on:cwd -> { at, repo }
  const worktrees = new Map(); // on:cwd -> { at, branches }
  const scanned = new Map(); // on:repo -> at, for worktree PRs
  let agents = [];
  let lastError = '';
  let mineAt = -Infinity;

  async function repoOf(agent) {
    const key = `${agent.on ?? ''}:${agent.cwd}`;
    const hit = remotes.get(key);
    if (hit && now() - hit.at < REMOTE_TTL_MS) return hit.repo;
    const repo = await remoteOf(agent.cwd, agent.on).catch(() => null);
    remotes.set(key, { at: now(), repo });
    return repo;
  }

  async function branchesOf(agent) {
    const key = `${agent.on ?? ''}:${agent.cwd}`;
    const hit = worktrees.get(key);
    if (hit && now() - hit.at < REMOTE_TTL_MS) return hit.branches;
    const branches = await worktreesOf(agent.cwd, agent.on).catch(() => []);
    worktrees.set(key, { at: now(), branches });
    return branches;
  }

  function track(url, branch) {
    const parsed = parsePrUrl(url);
    if (!parsed) return null;
    const entry = (tracked[parsed.url] ??= { url: parsed.url, repo: parsed.repo, number: parsed.number, branch: '', headSha: '', headSeenAt: now() });
    if (branch) entry.branch = branch;
    return entry;
  }

  // A working agent may open a PR at any moment; an idle one rarely does.
  async function discover(agent) {
    const { repo, branch } = agent;
    if (Object.values(tracked).some((t) => t.repo === repo && t.branch === branch)) return;
    const key = `${repo}:${branch}`;
    const wait = agent.status === 'working' ? DISCOVER_WORKING_MS : DISCOVER_IDLE_MS;
    if (now() - (discovered.get(key) ?? -Infinity) < wait) return;
    discovered.set(key, now());
    const url = await gh.discover(repo, branch).catch((error) => { lastError = error.message; return null; });
    if (!url) return;
    const entry = track(url, branch);
    store.save(tracked);
    await refresh(entry.url);
  }

  // An agent started in the repo's folder that then works in a worktree stays on the folder's branch.
  // So each repo's worktree branches are matched against its open PRs: one `gh pr list` per repo.
  async function discoverWorktrees(group) {
    const [first] = group, key = `${first.on ?? ''}:${first.repo}`;
    const wait = group.some((a) => a.status === 'working') ? DISCOVER_WORKING_MS : DISCOVER_IDLE_MS;
    if (now() - (scanned.get(key) ?? -Infinity) < wait) return;
    const own = new Set(group.map((a) => a.branch));
    const extra = new Set(group.flatMap((a) => a.worktrees).filter((b) => !own.has(b)));
    if (!extra.size) return;
    scanned.set(key, now());
    const prs = await gh.openPrs(first.repo).catch((error) => { lastError = error.message; return []; });
    const added = prs.filter((p) => extra.has(p.branch) && !tracked[parsePrUrl(p.url)?.url]).map((p) => track(p.url, p.branch)).filter(Boolean);
    if (!added.length) return;
    store.save(tracked);
    await inBatches(added, (e) => refresh(e.url));
  }

  // With `mine`, every open PR you authored is listed too, agent or not. One search every few minutes;
  // once listed, a PR refreshes like any other and leaves when it closes or 24 hours after a merge.
  async function discoverMine() {
    if (!settings.mine || now() - mineAt < MINE_MS) return;
    mineAt = now();
    const urls = await gh.mine().catch((error) => { lastError = error.message; return []; });
    let added = false;
    for (const url of urls) {
      const parsed = parsePrUrl(url);
      if (parsed && !tracked[parsed.url]) { track(url); added = true; }
    }
    if (added) store.save(tracked);
  }

  async function refresh(url) {
    const entry = tracked[url];
    if (!entry) return;
    try {
      const [pr, extra] = await Promise.all([gh.fetchPr(url), gh.fetchThreads(url)]);
      if (pr.headRefOid !== entry.headSha) {
        entry.headSha = pr.headRefOid;
        // A PR first seen long after its last commit should not wait for CI to appear.
        const committed = extra.headCommittedAt ? Date.parse(extra.headCommittedAt) : now();
        entry.headSeenAt = Math.min(committed, now());
      }
      entry.branch ||= pr.headRefName;
      const issues = (extra.issues ?? []).map((i) => ({ ...i, title: sanitize(i.title) }));
      live.set(url, { pr: clean(pr), threads: extra.threads, issues, fetchedAt: now() });
      lastError = '';
      if (pr.state === 'MERGED') await refreshFlow(url);
      prune();
    } catch (error) {
      lastError = error.message;
      live.set(url, { ...live.get(url), error: error.message, fetchedAt: now() });
    }
    store.save(tracked);
  }

  // After a merge only Actions changes, so this is all a merged PR costs. Jobs are fetched for
  // unfinished runs; a finished run's jobs are fetched once, when someone opens it.
  async function refreshFlow(url) {
    const entry = tracked[url];
    const sha = live.get(url)?.pr?.mergeCommit?.oid;
    if (!entry || !sha) return;
    const old = flows.get(url) ?? { runs: [], jobs: {} };
    const runs = await gh.fetchRuns(entry.repo, sha).catch(() => old.runs);
    const jobs = { ...old.jobs };
    await Promise.all(runs.filter((r) => r.status !== 'completed' || (old.runs.some((o) => o.id === r.id && o.status !== 'completed') && !jobs[r.id]?.final)).map(async (r) => {
      const list = await gh.fetchJobs(entry.repo, r.id).catch(() => null);
      if (list) jobs[r.id] = { jobs: list, final: r.status === 'completed' };
    }));
    flows.set(url, { runs, jobs, checkedAt: now() });
  }

  const flowBusy = (url) => {
    const pr = live.get(url)?.pr;
    return pr?.state === 'MERGED' && Boolean(pr.mergeCommit?.oid) && flowActive(flows.get(url)?.runs, pr.mergedAt, now());
  };

  async function loadJobs(url, runId) {
    const entry = tracked[url], flow = flows.get(url);
    if (!entry || !flow || flow.jobs[runId]?.final) return;
    const run = flow.runs.find((r) => r.id === runId);
    const list = await gh.fetchJobs(entry.repo, runId).catch(() => null);
    if (list) flow.jobs[runId] = { jobs: list, final: run?.status === 'completed' };
  }

  function prune() {
    for (const entry of Object.values(tracked)) {
      const pr = live.get(entry.url)?.pr;
      if (!pr) continue;
      const mergedAt = pr.mergedAt ? Date.parse(pr.mergedAt) : 0;
      if (pr.state === 'CLOSED' || (pr.state === 'MERGED' && now() - mergedAt > MERGED_KEEP_MS && !flowBusy(entry.url))) {
        delete tracked[entry.url];
        live.delete(entry.url);
        flows.delete(entry.url);
      }
    }
  }

  // The agent on the PR's branch; else the one agent whose repo has it in a worktree. With two
  // or more such agents nobody can tell which one made it, so none is attached.
  const agentFor = (entry) => {
    const mine = agents.filter((a) => a.repo === entry.repo && a.branch === entry.branch);
    if (mine.length) return mine.find((a) => a.status === 'working') ?? mine[0];
    const near = agents.filter((a) => a.repo === entry.repo && a.worktrees?.includes(entry.branch));
    return near.length === 1 ? near[0] : null;
  };

  async function inBatches(items, fn) {
    for (let i = 0; i < items.length; i += CONCURRENCY) await Promise.all(items.slice(i, i + CONCURRENCY).map(fn));
  }

  // One round: `list` is what the app says about its agents right now.
  async function tick(list) {
    const withRepo = await Promise.all(list.filter((a) => a.cwd).map(async (a) => {
      const repo = await repoOf(a);
      return { ...a, repo, worktrees: repo ? await branchesOf(a) : [] };
    }));
    agents = withRepo;
    // An agent that just finished has probably pushed or opened a PR, so look now.
    const finished = agents.filter((a) => previous.get(a.address) === 'working' && a.status !== 'working');
    for (const a of finished) {
      if (a.repo && a.branch) discovered.delete(`${a.repo}:${a.branch}`);
      if (a.repo) scanned.delete(`${a.on ?? ''}:${a.repo}`);
    }
    for (const a of agents) previous.set(a.address, a.status);
    const seen = new Set();
    const unique = agents.filter((a) => {
      const key = `${a.repo}:${a.branch}`;
      if (!a.repo || !a.branch || seen.has(key)) return false;
      seen.add(key);
      return true;
    });
    await inBatches(unique, discover);
    const repos = new Map();
    for (const a of agents) if (a.repo) { const k = `${a.on ?? ''}:${a.repo}`; repos.set(k, [...(repos.get(k) ?? []), a]); }
    await inBatches([...repos.values()], discoverWorktrees);
    await discoverMine();
    const fresh = new Set(finished.flatMap((a) => Object.values(tracked).filter((t) => t.repo === a.repo && t.branch === a.branch).map((t) => t.url)));
    const due = Object.values(tracked).filter((entry) => {
      const data = live.get(entry.url);
      if (!data) return true;
      if (['MERGED', 'CLOSED'].includes(data.pr?.state)) return false;
      if (fresh.has(entry.url)) return true;
      return now() - data.fetchedAt >= settings.pollMs * (agentFor(entry) ? 1 : SETTLED_FACTOR);
    });
    await inBatches(due, (e) => refresh(e.url));
    const flowing = Object.values(tracked).filter((e) => !due.includes(e) && flowBusy(e.url) && now() - (flows.get(e.url)?.checkedAt ?? -Infinity) >= FLOW_POLL_MS);
    await inBatches(flowing, (e) => refreshFlow(e.url));
    prune();
  }

  // Open PRs by latest activity, then merged ones.
  function cards() {
    const out = [];
    for (const entry of Object.values(tracked)) {
      const data = live.get(entry.url);
      const agent = agentFor(entry);
      const base = { key: entry.url, url: entry.url, repo: entry.repo, number: entry.number, agent };
      if (!data?.pr) {
        out.push({ ...base, loading: true, error: data?.error });
        continue;
      }
      const status = prState(data.pr, { now: now(), headSeenAt: entry.headSeenAt, threads: data.threads }, settings);
      const flow = data.pr.state === 'MERGED' && data.pr.mergeCommit?.oid ? { ...(flows.get(entry.url) ?? { runs: [], jobs: {} }), active: flowBusy(entry.url) } : null;
      out.push({ ...base, pr: data.pr, threads: data.threads, issues: data.issues ?? [], status, flow });
    }
    const rank = (c) => (c.pr?.state === 'MERGED' && !c.flow?.active ? 1 : 0);
    const time = (c) => Date.parse(c.pr?.updatedAt ?? 0) || 0;
    return out.sort((a, b) => rank(a) - rank(b) || time(b) - time(a));
  }

  return {
    tick,
    refresh,
    loadJobs,
    refreshAll: () => inBatches(Object.values(tracked), (e) => refresh(e.url)),
    track,
    cards,
    lastError: () => lastError,
  };
}
