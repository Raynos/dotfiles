const STRINGS = {
  en: {
    title: 'Pull requests', back: 'List', agent_go: 'Go', progress: 'Progress', comments_open: (n) => `Open comments ${n}`,
    files: (n) => `Changed files ${n}`, description: 'Description', failed_log: (name) => `Failed log · ${name}`, loading: 'Loading…',
    pr_opened: 'PR opened', draft: 'Draft', closed: 'Closed', merged: 'Merged', merge: 'Merge', review: 'Review', ready: 'Ready to merge', conflict: 'Merge conflict',
    behind: 'Behind base', blocked: 'Blocked by rules',
    ci: 'CI', ci_passed: 'CI passed', ci_failed: 'CI failed', ci_running: 'CI running', ci_none: 'No CI',
    r_approved: 'Approved', r_changes: 'Changes requested', r_ai: 'AI reviewing', r_wait: 'Waiting for review', r_reviewed: 'Reviewed', r_none: 'No review',
    n_checks: (n) => `${n} checks`, n_of: (done, total) => `${done} of ${total} finished`, failed_names: (total, names) => `${names} failed (of ${total})`,
    a_working: 'working', a_idle: 'idle', a_done: 'finished', a_blocked: 'needs input', a_unknown: 'unknown',
    empty_title: 'No pull requests yet', empty_body: 'A PR appears here when an agent has one open on its branch.',
    gh_title: 'GitHub CLI is not ready', gh_body: 'Run gh auth login in a terminal, then refresh.',
    no_diff: 'No text changes.', diff_failed: 'Could not load the changes. Open the PR on GitHub.', log_failed: 'Could not load the log. Open it on GitHub.', open_github: 'Open on GitHub', log_more: 'Full log',
    flow_done: (n) => `${n} runs after merge finished`, flow_failed: (name) => `${name} failed`, flow_more: (n) => `+${n} more`, flow_checking: 'Checking for runs…', flow_waiting: 'waiting for approval', flow_queued: 'queued', flow_cancelled: 'cancelled', flow_failed_note: 'failed', run_log: 'Show log', merged_to: (base) => `Merged → ${base}`,
    checks: (n) => `Checks ${n}`, issues: (n) => `Linked issues ${n}`, issues_none: 'No linked issues', issue_none: 'No issue', issue_one: (n) => `Issue #${n}`, issue_many: (n) => `${n} issues`, issue_open: 'Open', issue_closed: 'Closed', issue_not_planned: 'Not planned', issue_comments: (n) => `Comments ${n}`, issue_failed: 'Could not load this issue. Open it on GitHub.',
    org_all: 'All', repo_all: 'All repos',
    comment_hint: 'Click a line to comment', comment_on: (where) => `Comment on ${where}`, comment_placeholder: 'Leave feedback', comment_send: 'Send', comment_sending: 'Sending…', comment_cancel: 'Cancel',
    merge_do: (m) => `Merge (${m})`, merge_confirm: 'Press again to merge', merging: 'Merging…',
    update_pill: (tag) => `Update ${tag}`, version: 'Version', update_title: (tag) => `PR Flow ${tag} is out`, update_have: (v) => `You have v${v}. To update, ask your Herdr agent:`, update_changed: 'What changed', update_no_notes: 'See the release page.', update_copy: 'Copy prompt', update_copied: 'Copied', update_page: 'Release page', update_later: 'Later', update_check: 'Check for new versions', update_latest: (v) => `v${v} · up to date`, update_off: (v) => `v${v}`,
    settings: 'Settings', language: 'Language', lang_auto: 'Follow system', just_now: 'just now', ago: (n, u) => `${n}${{ m: 'm', h: 'h', d: 'd' }[u]} ago`, close: 'Close',
  },
  ko: {
    title: 'Pull requests', back: '목록', agent_go: '이동', progress: '처리 과정', comments_open: (n) => `안 끝난 코멘트 ${n}`,
    files: (n) => `변경 파일 ${n}`, description: '설명', failed_log: (name) => `실패한 로그 · ${name}`, loading: '불러오는 중…',
    pr_opened: 'PR 열림', draft: '초안', closed: '닫힘', merged: '머지됨', merge: '머지', review: '리뷰', ready: '머지 가능', conflict: '머지 충돌',
    behind: '기준 브랜치보다 뒤처짐', blocked: '브랜치 규칙에 막힘',
    ci: 'CI', ci_passed: 'CI 통과', ci_failed: 'CI 실패', ci_running: 'CI 실행 중', ci_none: 'CI 없음',
    r_approved: '승인', r_changes: '변경 요청', r_ai: 'AI 리뷰 중', r_wait: '리뷰 대기', r_reviewed: '리뷰됨', r_none: '리뷰 없음',
    n_checks: (n) => `${n}개`, n_of: (done, total) => `${total}개 중 ${done}개 끝남`, failed_names: (total, names) => `${total}개 중 ${names} 실패`,
    a_working: '작업 중', a_idle: '대기 중', a_done: '끝남', a_blocked: '입력 필요', a_unknown: '알 수 없음',
    empty_title: '아직 PR이 없습니다', empty_body: '에이전트의 브랜치에 PR이 올라오면 여기에 나타납니다.',
    gh_title: 'GitHub CLI를 쓸 수 없습니다', gh_body: '터미널에서 gh auth login을 실행한 뒤 새로고침하세요.',
    no_diff: '텍스트 변경이 없습니다.', diff_failed: '변경 내용을 불러오지 못했습니다. GitHub에서 확인하세요.', log_failed: '로그를 불러오지 못했습니다. GitHub에서 확인하세요.', open_github: 'GitHub에서 열기', log_more: '전체 로그',
    flow_done: (n) => `머지 후 실행 ${n}개 완료`, flow_failed: (name) => `${name} 실패`, flow_more: (n) => `외 ${n}개`, flow_checking: '실행 확인 중…', flow_waiting: '승인 대기', flow_queued: '대기 중', flow_cancelled: '취소됨', flow_failed_note: '실패', run_log: '로그 보기', merged_to: (base) => `머지됨 → ${base}`,
    checks: (n) => `체크 ${n}`, issues: (n) => `연결된 이슈 ${n}`, issues_none: '연결된 이슈 없음', issue_none: '이슈 없음', issue_one: (n) => `이슈 #${n}`, issue_many: (n) => `이슈 ${n}개`, issue_open: '열림', issue_closed: '닫힘', issue_not_planned: '계획 안 함', issue_comments: (n) => `코멘트 ${n}`, issue_failed: '이슈를 불러오지 못했습니다. GitHub에서 확인하세요.',
    org_all: '전체', repo_all: '모든 레포',
    comment_hint: '줄을 누르면 코멘트를 남길 수 있습니다', comment_on: (where) => `${where} 코멘트`, comment_placeholder: '피드백을 입력하세요', comment_send: '보내기', comment_sending: '보내는 중…', comment_cancel: '취소',
    merge_do: (m) => `머지 (${m})`, merge_confirm: '한 번 더 누르면 머지', merging: '머지하는 중…',
    update_pill: (tag) => `${tag} 업데이트`, version: '버전', update_title: (tag) => `PR Flow ${tag} 나왔습니다`, update_have: (v) => `지금은 v${v}입니다. 업데이트하려면 Herdr 에이전트에게 이렇게 말하세요:`, update_changed: '바뀐 점', update_no_notes: '릴리스 페이지를 보세요.', update_copy: '프롬프트 복사', update_copied: '복사했습니다', update_page: '릴리스 페이지', update_later: '나중에', update_check: '새 버전 확인', update_latest: (v) => `v${v} · 최신 버전`, update_off: (v) => `v${v}`,
    settings: '설정', language: '언어', lang_auto: '시스템 언어 따르기', just_now: '방금', ago: (n, u) => `${n}${{ m: '분', h: '시간', d: '일' }[u]} 전`, close: '닫기',
  },
};

export function translator(lang) {
  const table = STRINGS[lang] ?? STRINGS.en;
  return (key, ...args) => {
    const value = table[key] ?? STRINGS.en[key] ?? key;
    return typeof value === 'function' ? value(...args) : value;
  };
}

// The choice saved in settings wins; "auto" or nothing saved follows the system.
export function effectiveLang(choice, system) {
  return choice === 'ko' || choice === 'en' ? choice : system === 'ko' ? 'ko' : 'en';
}

export function relative(ms, t) {
  const m = Math.floor(Math.max(0, ms) / 60_000);
  if (m < 1) return t('just_now');
  if (m < 60) return t('ago', m, 'm');
  if (m < 1440) return t('ago', Math.floor(m / 60), 'h');
  return t('ago', Math.floor(m / 1440), 'd');
}
