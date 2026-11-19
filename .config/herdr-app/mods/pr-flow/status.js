// Turns a pull request into plain facts about where it is. Nothing here judges what the
// reader should do, and a check that does not exist is reported as missing, never as passed.

const FAILED_CONCLUSIONS = new Set(['FAILURE', 'TIMED_OUT', 'CANCELLED', 'ACTION_REQUIRED', 'STARTUP_FAILURE']);
const FAILED_STATES = new Set(['FAILURE', 'ERROR']);
// AI review often runs as a CI job. Its result says nothing about whether the code builds.
const AI_CHECK = /(claude|copilot|coderabbit|codex|gemini|cursor|greptile|\bai\b)[-_ /]*(code[-_ ]*)?review|review[-_ /]*(claude|copilot|codex|gemini|\bai\b)/i;

export function checkState(check) {
  if (check.__typename === 'StatusContext' || check.state) {
    if (FAILED_STATES.has(check.state)) return 'failed';
    return check.state === 'SUCCESS' ? 'passed' : 'running';
  }
  if (check.status !== 'COMPLETED') return 'running';
  return FAILED_CONCLUSIONS.has(check.conclusion) ? 'failed' : 'passed';
}

export function isAiCheck(check, settings) {
  const name = String(check.name ?? check.context ?? '').toLowerCase();
  return AI_CHECK.test(name) || settings.aiChecks.includes(name);
}

function describeCheck(check, settings) {
  return {
    name: check.name ?? check.context ?? 'check',
    state: checkState(check),
    at: check.completedAt ?? check.startedAt ?? null,
    ai: isAiCheck(check, settings),
    url: check.detailsUrl ?? check.targetUrl ?? '',
  };
}

export function ciSummary(pr, ctx, settings) {
  const checks = (pr.statusCheckRollup ?? []).map((c) => describeCheck(c, settings));
  const ci = checks.filter((c) => !c.ai);
  const failed = ci.filter((c) => c.state === 'failed');
  const passed = ci.filter((c) => c.state === 'passed').length;
  let kind;
  if (!ci.length) kind = ctx.now - ctx.headSeenAt < settings.ciWaitMs ? 'running' : 'none';
  else if (failed.length) kind = 'failed';
  else kind = ci.some((c) => c.state === 'running') ? 'running' : 'passed';
  return { kind, checks: ci, ai: checks.filter((c) => c.ai), failed, passed, total: ci.length };
}

export function reviewSummary(pr, ci) {
  const aiRunning = ci.ai.some((c) => c.state === 'running');
  const reviewed = (pr.latestReviews ?? []).length > 0 || ci.ai.some((c) => c.state === 'passed');
  if (pr.reviewDecision === 'APPROVED') return 'approved';
  if (pr.reviewDecision === 'CHANGES_REQUESTED') return 'changes';
  if (aiRunning) return 'ai_running';
  if (pr.reviewDecision === 'REVIEW_REQUIRED') return 'required';
  return reviewed ? 'reviewed' : 'none';
}

// The single fact shown after the arrow, most blocking first.
export function prState(pr, ctx, settings) {
  const ci = ciSummary(pr, ctx, settings);
  const review = reviewSummary(pr, ci);
  const comments = (ctx.threads ?? []).filter((t) => !t.isResolved && !t.isOutdated).length;
  const state = String(pr.state ?? 'OPEN').toUpperCase();
  const base = { ci, review, comments };
  const at = (name, tone, extra = {}) => ({ ...base, ...extra, name, tone });

  if (state === 'MERGED') return at('merged', 'pur');
  if (state === 'CLOSED') return at('closed', 'f1');
  if (pr.isDraft) return at('draft', 'f1');
  if (pr.mergeable === 'CONFLICTING') return at('conflict', 'bad');
  if (ci.kind === 'failed') return at('ci_failed', 'bad', { count: ci.failed.length });
  if (ci.kind === 'running') return at('ci_running', 'cya');
  if (review === 'changes') return at('changes', 'bad');
  if (comments) return at('comments', 'warn', { count: comments });
  if (review === 'ai_running') return at('ai_running', 'cya');
  if (review === 'required') return at('review_wait', 'cya');
  if (pr.mergeStateStatus === 'BEHIND') return at('behind', 'warn');
  if (pr.mergeStateStatus === 'BLOCKED') return at('blocked', 'warn');
  return at('ready', 'ok');
}
