// FlixGo download server — no npm dependencies. Requires: Node 18+, yt-dlp, ffmpeg.
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { execFile } = require('child_process');

const PORT = Number(process.env.PORT || 8787);
const PUBLIC_URL = process.env.PUBLIC_URL || ''; // e.g. https://api.example.com
const YTDLP = process.env.YTDLP_BIN || 'yt-dlp';
const DIR = process.env.FILES_DIR || path.join(os.tmpdir(), 'flixgo-files');
const ALLOWED = (process.env.ALLOWED_HOSTS ||
  'youtube.com,youtu.be,instagram.com,tiktok.com,x.com,twitter.com,facebook.com,fb.com,fb.watch')
  .split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
const MAX_JOBS = Number(process.env.MAX_JOBS || 3);
const TTL_MS = 30 * 60 * 1000;
const HEIGHTS = { '360p': 360, '720p': 720, '1080p': 1080, '4K': 2160 };
const TYPES = { mp4: 'video/mp4', mkv: 'video/x-matroska', webm: 'video/webm', mp3: 'audio/mpeg', m4a: 'audio/mp4' };

fs.mkdirSync(DIR, { recursive: true });
let jobs = 0;
let infoJobs = 0;

function isAllowedHost(host) {
  host = host.toLowerCase();
  return ALLOWED.some((h) => host === h || host.endsWith('.' + h));
}

function send(res, status, obj) {
  if (res.destroyed || res.headersSent) return;
  const body = JSON.stringify(obj);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (c) => {
      data += c;
      if (data.length > 10_000) { reject(new Error('Body too large')); req.destroy(); }
    });
    req.on('end', () => { try { resolve(JSON.parse(data || '{}')); } catch { reject(new Error('Invalid JSON')); } });
    req.on('error', reject);
  });
}

function lastLine(err, stderr) {
  const last = String(stderr || err.message).trim().split('\n').filter(Boolean).pop() || 'yt-dlp failed';
  return last.replace(/^ERROR:\s*/, '');
}

// Validates body.url; sends an error response and returns null when not allowed.
function parseAllowedUrl(body, res) {
  let parsed;
  try { parsed = new URL(String(body.url || '')); } catch { send(res, 400, { error: 'Invalid URL' }); return null; }
  if (!['http:', 'https:'].includes(parsed.protocol)) { send(res, 400, { error: 'Only http/https links are allowed' }); return null; }
  if (!isAllowedHost(parsed.hostname)) { send(res, 400, { error: 'This website is not supported' }); return null; }
  return parsed;
}

function runYtDlp(url, quality, audioOnly, id, ctl) {
  const args = ['--no-playlist', '--no-warnings', '--no-progress', '-o', path.join(DIR, `${id}.%(ext)s`)];
  if (audioOnly) {
    const kbps = parseInt(quality, 10);
    const abr = [128, 192, 320].includes(kbps) ? `${kbps}K` : '192K';
    args.push('-f', 'ba/b', '-x', '--audio-format', 'mp3', '--audio-quality', abr);
  } else {
    const h = HEIGHTS[quality] || 720;
    args.push('-f', 'bv*+ba/b', '-S', `res:${h},vcodec:h264,acodec:m4a`, '--merge-output-format', 'mp4');
  }
  args.push('--print', 'after_move:filepath', '--print', 'after_move:title', '--', url);
  return new Promise((resolve, reject) => {
    ctl.child = execFile(YTDLP, args, { timeout: 10 * 60 * 1000, maxBuffer: 5 * 1024 * 1024 }, (err, stdout, stderr) => {
      if (ctl.cancelled) return reject(new Error('Cancelled'));
      if (err) return reject(new Error(lastLine(err, stderr)));
      const [filepath, ...rest] = stdout.trim().split('\n');
      resolve({ filepath: filepath.trim(), title: rest.join(' ').trim() });
    });
  });
}

function runInfo(url, ctl) {
  const args = [
    '--no-playlist', '--no-warnings', '--skip-download', '--ignore-no-formats-error',
    '--print', '%(title)j', '--print', '%(thumbnail)j',
    '--print', '%(duration)j', '--print', '%(uploader)j',
    '--', url,
  ];
  return new Promise((resolve, reject) => {
    ctl.child = execFile(YTDLP, args, { timeout: 40 * 1000, maxBuffer: 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) return reject(new Error(lastLine(err, stderr)));
      const lines = stdout.trim().split('\n');
      const pick = (i) => {
        try { const v = JSON.parse(lines[i]); return v === null || v === undefined ? '' : v; } catch { return ''; }
      };
      resolve({
        title: String(pick(0)).slice(0, 200),
        thumbnail: String(pick(1)),
        duration: Number(pick(2)) || 0,
        uploader: String(pick(3)).slice(0, 80),
      });
    });
  });
}

async function handleInfo(req, res) {
  let body;
  try { body = await readJson(req); } catch (e) { return send(res, 400, { error: e.message }); }
  const parsed = parseAllowedUrl(body, res);
  if (!parsed) return;
  if (infoJobs >= 4) return send(res, 429, { error: 'Server is busy, try again shortly' });

  const ctl = { child: null };
  res.on('close', () => { if (!res.writableFinished && ctl.child) ctl.child.kill('SIGKILL'); });
  infoJobs++;
  try {
    send(res, 200, await runInfo(parsed.href, ctl));
  } catch (e) {
    send(res, 502, { error: e.message });
  } finally {
    infoJobs--;
  }
}

async function handleDownload(req, res) {
  let body;
  try { body = await readJson(req); } catch (e) { return send(res, 400, { error: e.message }); }
  const parsed = parseAllowedUrl(body, res);
  if (!parsed) return;
  if (jobs >= MAX_JOBS) return send(res, 429, { error: 'Server is busy, try again shortly' });

  // If the app cancels (closes the connection), stop yt-dlp right away.
  const ctl = { child: null, cancelled: false };
  res.on('close', () => {
    if (!res.writableFinished) {
      ctl.cancelled = true;
      if (ctl.child) ctl.child.kill('SIGKILL');
    }
  });

  const id = crypto.randomBytes(8).toString('hex');
  jobs++;
  try {
    const { filepath, title } = await runYtDlp(parsed.href, String(body.quality || ''), body.audioOnly === true, id, ctl);
    const stored = path.basename(filepath);
    if (!stored.startsWith(id) || !fs.existsSync(path.join(DIR, stored))) throw new Error('Output file not found');
    const ext = path.extname(stored);
    const base = (PUBLIC_URL || `http://${req.headers.host}`).replace(/\/$/, '');
    const safeTitle = (title || 'flixgo').replace(/[\\/:*?"<>|\x00-\x1F]/g, '_').slice(0, 80);
    send(res, 200, { downloadUrl: `${base}/files/${stored}`, fileName: `${safeTitle}${ext}`, title: (title || '').slice(0, 200) });
  } catch (e) {
    send(res, 502, { error: e.message });
  } finally {
    jobs--;
  }
}

function handleFile(req, res) {
  let name;
  try { name = decodeURIComponent(req.url.split('?')[0].slice('/files/'.length)); }
  catch { return send(res, 400, { error: 'Bad request' }); }
  if (!/^[a-f0-9]{16}\.[a-z0-9]{2,4}$/.test(name)) return send(res, 404, { error: 'Not found' });
  const file = path.join(DIR, name);
  fs.stat(file, (err, st) => {
    if (err) return send(res, 404, { error: 'Not found' });
    res.writeHead(200, { 'Content-Type': TYPES[name.split('.').pop()] || 'application/octet-stream', 'Content-Length': st.size });
    const stream = fs.createReadStream(file);
    stream.on('error', () => res.destroy());
    res.on('close', () => stream.destroy());
    stream.pipe(res);
  });
}

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/api/download') return handleDownload(req, res);
  if (req.method === 'POST' && req.url === '/api/info') return handleInfo(req, res);
  if (req.method === 'GET' && req.url.startsWith('/files/')) return handleFile(req, res);
  if (req.method === 'GET' && req.url === '/health') return send(res, 200, { ok: true });
  send(res, 404, { error: 'Not found' });
});
server.requestTimeout = 0;

setInterval(() => {
  for (const f of fs.readdirSync(DIR)) {
    const p = path.join(DIR, f);
    try { if (Date.now() - fs.statSync(p).mtimeMs > TTL_MS) fs.unlinkSync(p); } catch {}
  }
}, 5 * 60 * 1000).unref();

server.listen(PORT, '0.0.0.0', () => console.log(`FlixGo server on :${PORT}`));