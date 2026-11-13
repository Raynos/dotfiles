#!/usr/bin/env node
'use strict';
// tsc-lsp-proxy: sits between the editor and `tsc --lsp --stdio`.
//  1. Starts the real server with GOMAXPROCS and GOMEMLIMIT set.
//  2. Keeps the server to the window's workspace folders: document sync for
//     files outside them is not forwarded, and requests about those files are
//     answered here with an empty result.
// Server-to-client traffic is forwarded byte for byte and never parsed as JSON.
// No dependencies. Config is the constants below; TSLSP_* variables override them.
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { fileURLToPath } = require('node:url');

const GOMAXPROCS = process.env.TSLSP_GOMAXPROCS || '4';
// The editor setting js/ts.server.goMemLimit arrives here as GOMEMLIMIT and wins over the default.
const GOMEMLIMIT = process.env.TSLSP_GOMEMLIMIT || process.env.GOMEMLIMIT || '4GiB';
const FILTER = process.env.TSLSP_FILTER !== '0';
// Extra directories to treat as inside the workspace: one per line in this file, read at server start.
const EXTRA_ROOTS_FILE = path.join(os.homedir(), '.config', 'tsc-lsp-proxy', 'extra-roots');
const readLines = file => { try { return fs.readFileSync(file, 'utf8').split('\n'); } catch { return []; } };
const EXTRA_ROOTS = (process.env.TSLSP_EXTRA_ROOTS?.split(':') ?? readLines(EXTRA_ROOTS_FILE)).map(s => s.trim()).filter(s => s.startsWith('/'));
// Severity of the one-line notice returned as diagnostics for a filtered file:
// 3 = information, 4 = hint, 0 = return no diagnostics at all.
const NOTICE_SEVERITY = Number(process.env.TSLSP_NOTICE ?? 3);
const NOTICE = 'TypeScript is off for this file: it is outside this window\'s workspace folders (tsc-lsp-proxy).';
const CASE_INSENSITIVE = process.platform === 'darwin' || process.platform === 'win32';

const log = text => process.stderr.write(`[tsc-lsp-proxy] ${text}\n`);

function findRealServer() {
    if (process.env.TSLSP_REAL) return process.env.TSLSP_REAL;
    const found = [];
    for (const editor of ['.cursor', '.vscode']) {
        const dir = path.join(os.homedir(), editor, 'extensions');
        let names = [];
        try { names = fs.readdirSync(dir); } catch { /* editor not installed */ }
        for (const name of names) {
            const exe = path.join(dir, name, 'lib', 'tsc');
            if (/^typescriptteam\.native-preview-/i.test(name) && fs.existsSync(exe)) found.push(exe);
        }
    }
    found.sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
    return found.pop();
}

const real = findRealServer();
const args = process.argv.slice(2);
if (!real) { log('no server binary found; set TSLSP_REAL'); process.exit(1); }
const isLsp = args.includes('--lsp') && args.includes('--stdio');
const child = spawn(real, args, {
    stdio: isLsp ? ['pipe', 'pipe', 'inherit'] : 'inherit',
    env: { ...process.env, GOMAXPROCS, GOMEMLIMIT },
});
child.on('error', err => { log(`cannot start ${real}: ${err.message}`); process.exit(1); });
child.on('close', (code, signal) => process.stdout.write('', () => process.exit(code ?? (signal ? 1 : 0))));
for (const sig of ['SIGTERM', 'SIGINT', 'SIGHUP']) process.on(sig, () => child.kill(sig));
if (isLsp) startProxy();

function startProxy() {
    log(`server=${real} GOMAXPROCS=${GOMAXPROCS} GOMEMLIMIT=${GOMEMLIMIT} filter=${FILTER}`);
    let roots = [];             // normalised workspace folder paths
    const opened = new Set();   // URIs whose didOpen was forwarded
    const dropped = new Set();  // URIs whose didOpen was dropped

    const norm = p => { p = p.replace(/\/+$/, ''); return CASE_INSENSITIVE ? p.toLowerCase() : p; };
    const uriToPath = uri => { try { return norm(fileURLToPath(uri)); } catch { return undefined; } };
    const setRoots = params => {
        let found = (params.workspaceFolders ?? []).map(f => uriToPath(f.uri)).filter(Boolean);
        if (!found.length && params.rootUri) found = [uriToPath(params.rootUri)].filter(Boolean);
        if (!found.length && params.rootPath) found = [norm(params.rootPath)];
        roots = found.length ? found.concat(EXTRA_ROOTS.map(norm)) : [];
        log(`workspace roots: ${roots.join(', ') || '(none, filter off)'}`);
    };
    const isOutside = uri => {
        if (!FILTER || roots.length === 0 || typeof uri !== 'string' || !uri.startsWith('file://')) return false;
        const p = uriToPath(uri);
        return p !== undefined && !roots.some(r => p === r || p.startsWith(r + '/'));
    };
    const emptyResult = method => {
        if (method !== 'textDocument/diagnostic') return null;
        const zero = { line: 0, character: 0 };
        const items = NOTICE_SEVERITY ? [{ range: { start: zero, end: zero }, severity: NOTICE_SEVERITY, source: 'tsc-lsp-proxy', message: NOTICE }] : [];
        return { kind: 'full', items };
    };

    const toServer = makeWriter(process.stdin, child.stdin);
    const toClient = makeWriter(child.stdout, process.stdout);
    const reply = (id, result) => {
        const body = Buffer.from(JSON.stringify({ jsonrpc: '2.0', id, result }));
        toClient(Buffer.concat([Buffer.from(`Content-Length: ${body.length}\r\n\r\n`), body]));
    };

    // Returns true when the message has been handled here and must not reach the server.
    function intercept(msg) {
        if (msg.method === 'initialize') { setRoots(msg.params ?? {}); return false; }
        if (msg.method === 'workspace/didChangeWorkspaceFolders') {
            const event = msg.params?.event ?? {};
            const gone = new Set((event.removed ?? []).map(f => uriToPath(f.uri)));
            roots = roots.filter(r => !gone.has(r)).concat((event.added ?? []).map(f => uriToPath(f.uri)).filter(Boolean));
            log(`workspace roots: ${roots.join(', ')}`);
            return false;
        }
        if (typeof msg.method !== 'string') return false;   // a response to a server request
        // File create, rename and delete events name files, not an open document.
        const files = /^workspace\/(will|did)(Create|Rename|Delete)Files$/.test(msg.method) ? msg.params?.files : undefined;
        if (Array.isArray(files) && files.length && files.every(f => isOutside(f.oldUri ?? f.uri))) {
            if (msg.id !== undefined) reply(msg.id, null);
            return true;
        }
        const uri = msg.params?.textDocument?.uri;
        if (typeof uri !== 'string') return false;
        if (msg.method === 'textDocument/didOpen') {
            if (!isOutside(uri)) { opened.add(uri); return false; }
            dropped.add(uri);
            log(`not opening ${uri} (${dropped.size} filtered documents)`);
            return true;
        }
        // The decision made at didOpen holds until didClose, even if the folders change in between.
        const filtered = dropped.has(uri) || (!opened.has(uri) && isOutside(uri));
        if (msg.method === 'textDocument/didClose') { opened.delete(uri); dropped.delete(uri); }
        if (!filtered) return false;
        if (msg.id !== undefined) reply(msg.id, emptyResult(msg.method));
        return true;
    }

    process.stdin.on('data', framer((frame, body) => {
        let handled = false;
        try { handled = intercept(JSON.parse(body.toString('utf8'))); }
        catch (err) { log(`passing a message through unread: ${err.message}`); }
        if (!handled) toServer(frame);
    }));
    process.stdin.on('end', () => child.stdin.end());
    child.stdout.on('data', framer(frame => toClient(frame)));
    child.stdin.on('error', () => { /* server went away; the close handler exits */ });
    process.stdout.on('error', () => child.kill());
}

// Splits a byte stream into LSP frames. onFrame gets the whole frame and its JSON body.
function framer(onFrame) {
    let chunks = [], size = 0, need = 0;
    return chunk => {
        chunks.push(chunk);
        size += chunk.length;
        if (size < need) return;
        let buf = chunks.length === 1 ? chunks[0] : Buffer.concat(chunks, size);
        for (;;) {
            need = 0;
            const headerEnd = buf.indexOf('\r\n\r\n');
            if (headerEnd < 0) break;
            const match = /content-length: *(\d+)/i.exec(buf.latin1Slice(0, headerEnd));
            if (!match) { log('message header without Content-Length; giving up'); child.kill(); process.exit(1); }
            const end = headerEnd + 4 + Number(match[1]);
            if (buf.length < end) { need = end; break; }
            onFrame(buf.subarray(0, end), buf.subarray(headerEnd + 4, end));
            buf = buf.subarray(end);
        }
        chunks = buf.length ? [buf] : [];
        size = buf.length;
    };
}

// Writes to dst and pauses src while dst is backed up.
function makeWriter(src, dst) {
    let waiting = false;
    return buf => {
        if (dst.write(buf) || waiting) return;
        waiting = true;
        src.pause();
        dst.once('drain', () => { waiting = false; src.resume(); });
    };
}
