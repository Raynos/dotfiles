// Parses `gh pr diff` output into files and numbered lines.
export function parseDiff(text) {
  const files = [];
  let file = null;
  let oldNo = 0;
  let newNo = 0;
  for (const line of String(text ?? '').split('\n')) {
    if (line.startsWith('diff --git ')) {
      const m = /^diff --git a\/(.+) b\/(.+)$/.exec(line);
      file = { path: m ? m[2] : line.slice(11), added: 0, removed: 0, lines: [] };
      files.push(file);
      continue;
    }
    if (!file) continue;
    if (line.startsWith('rename to ')) {
      file.path = line.slice(10);
      continue;
    }
    if (line.startsWith('Binary files')) {
      file.lines.push({ kind: 'meta', text: 'Binary file not shown.' });
      continue;
    }
    const hunk = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@(.*)$/.exec(line);
    if (hunk) {
      oldNo = Number(hunk[1]);
      newNo = Number(hunk[2]);
      file.lines.push({ kind: 'hunk', text: hunk[3].trim() });
      continue;
    }
    if (file.lines.length === 0) continue;
    if (line.startsWith('+')) {
      file.added += 1;
      file.lines.push({ kind: 'add', newNo: newNo++, text: line.slice(1) });
    } else if (line.startsWith('-')) {
      file.removed += 1;
      file.lines.push({ kind: 'del', oldNo: oldNo++, text: line.slice(1) });
    } else if (line.startsWith(' ')) {
      file.lines.push({ kind: 'ctx', oldNo: oldNo++, newNo: newNo++, text: line.slice(1) });
    }
  }
  return files;
}

// What a review comment on this line needs: GitHub's line number and side. Null for headers.
export function commentTarget(line) {
  if (line?.kind === 'add' || line?.kind === 'ctx') return { line: line.newNo, side: 'RIGHT' };
  if (line?.kind === 'del') return { line: line.oldNo, side: 'LEFT' };
  return null;
}

// Long lines split so a comment reads without scrolling sideways.
function wrap(text, width) {
  const out = [];
  for (const line of String(text ?? '').split('\n')) {
    if (!line) { out.push(''); continue; }
    for (let i = 0; i < line.length; i += width) out.push(line.slice(i, i + width));
  }
  return out;
}

// A file's rows with its open review threads under the lines they're on. Rows stay one height:
// each comment becomes an author row and one row per line of text.
export function withComments(lines, threads, path, width = 90) {
  const open = (threads ?? []).filter((x) => x.path === path && x.line && !x.isResolved && !x.isOutdated);
  if (!open.length) return lines;
  const rows = [];
  for (const line of lines) {
    rows.push(line);
    const at = commentTarget(line);
    if (!at) continue;
    for (const thread of open) {
      if (thread.line !== at.line || (thread.diffSide ?? 'RIGHT') !== at.side) continue;
      for (const c of thread.comments?.nodes ?? []) {
        rows.push({ kind: 'comment-head', text: c.author?.login ?? '' });
        for (const text of wrap(c.body, width)) rows.push({ kind: 'comment', text });
      }
    }
  }
  return rows;
}
