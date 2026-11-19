// What GitHub Actions is doing with a merged PR. Nothing here knows what a repo's workflows
// are for: names come straight from the repo, so it needs no setup and never guesses "deployed".
const AUTO_STEP = /^(Set up job|Set up runner|Complete job|Post )/;
export const FLOW_GRACE_MS = 180_000;

export function runState(run) {
  if (run.status === 'completed') {
    if (run.conclusion === 'success' || run.conclusion === 'neutral') return 'ok';
    if (run.conclusion === 'skipped') return 'skipped';
    if (run.conclusion === 'cancelled') return 'cancelled';
    if (run.conclusion === 'action_required') return 'waiting';
    return 'bad';
  }
  if (run.status === 'waiting') return 'waiting';
  return run.status === 'in_progress' ? 'running' : 'queued';
}

export function visibleSteps(job) {
  return (job.steps ?? []).filter((s) => !AUTO_STEP.test(s.name) && s.conclusion !== 'skipped');
}

// Where a run is now: the step in progress, or the next one between steps.
export function position(jobs) {
  const job = (jobs ?? []).find((j) => j.status === 'in_progress');
  if (!job) return null;
  const steps = visibleSteps(job);
  if (!steps.length) return { job: job.name, step: '', index: 0, total: 0 };
  let i = steps.findIndex((s) => s.status === 'in_progress');
  if (i < 0) i = Math.min(steps.filter((s) => s.status === 'completed').length, steps.length - 1);
  return { job: job.name, step: steps[i].name, index: i + 1, total: steps.length };
}

const RANK = { bad: 0, running: 1, waiting: 2, queued: 3, cancelled: 4, ok: 5 };

export function orderedRuns(runs) {
  return (runs ?? []).filter((r) => runState(r) !== 'skipped').sort((a, b) => RANK[runState(a)] - RANK[runState(b)]);
}

export function flowSummary(runs) {
  const list = orderedRuns(runs);
  const of = (state) => list.filter((r) => runState(r) === state);
  const lead = list[0] ?? null;
  const unfinished = list.filter((r) => r.status !== 'completed');
  const kind = !list.length ? 'none' : of('bad').length ? 'failed' : unfinished.length ? 'active' : 'done';
  return { kind, lead, total: list.length, more: Math.max(0, kind === 'failed' ? of('bad').length - 1 + unfinished.length : unfinished.length - 1) };
}

// Runs show up a moment after a merge, and one workflow can start another when it ends.
export function flowActive(runs, mergedAt, now) {
  if ((runs ?? []).some((r) => r.status !== 'completed')) return true;
  const last = (runs ?? []).reduce((at, r) => Math.max(at, Date.parse(r.updatedAt) || 0), Date.parse(mergedAt) || 0);
  return now - last < FLOW_GRACE_MS;
}
