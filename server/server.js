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
const MAX_JOBS = Number(process.env.MAX_JOBS || 3);
const TTL_MS = 30 * 60 * 1000;
const HEIGHTS = { '360p': 360, '720p': 720, '1080p': 1080, '4K': 2160 };
const TYPES = { mp4: 'video/mp4', mkv: 'video/x-matroska', webm: 'video/webm', mp3: 'audio/mpeg', m4a: 'audio/mp4' };

fs.mkdirSync(DIR, { recursive: true });
let jobs = 0;

function send(res, status, obj) {
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

function runYtDlp(url, quality, audioOnly, id) {
  const args = ['--no-playlist', '--no-warnings', '--no-progress', '-o', path.join(DIR, `${id}.%(ext)s`)];
  if (audioOnly) {
    args.push('-f', 'ba/b', '-x', '--audio-format', 'mp3');
  } else {
    const h = HEIGHTS[quality] || 720;
    args.push('-f', 'bv*+ba/b', '-S', `res:${h},vcodec:h264,acodec:m4a`, '--merge-output-format', 'mp4');
  }
  args.push('--print', 'after_move:filepath', '--print', 'after_move:title', '--', url);
  return new Promise((resolve, reject) => {
    execFile(YTDLP, args, { timeout: 10 * 60 * 1000, maxBuffer: 5 * 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) {
        const last = String(stderr || err.message).trim().split('\n').filter(Boolean).pop() || 'yt-dlp failed';
        return reject(new Error(last.replace(/^ERROR:\s*/, '')));
      }
      const [filepath, ...rest] = stdout.trim().split('\n');
      resolve({ filepath: filepath.trim(), title: rest.join(' ').trim() });
    });
  });
}

async function handleDownload(req, res) {
  let body;
  try { body = await readJson(req); } catch (e) { return send(res, 400, { error: e.message }); }
  let parsed;
  try { parsed = new URL(String(body.url || '')); } catch { return send(res, 400, { error: 'Invalid URL' }); }
  if (!['http:', 'https:'].includes(parsed.protocol)) return send(res, 400, { error: 'Only http/https links are allowed' });
  if (jobs >= MAX_JOBS) return send(res, 429, { error: 'Server is busy, try again shortly' });

  const id = crypto.randomBytes(8).toString('hex');
  jobs++;
  try {
    const { filepath, title } = await runYtDlp(parsed.href, String(body.quality || ''), body.audioOnly === true, id);
    const stored = path.basename(filepath);
    if (!stored.startsWith(id) || !fs.existsSync(path.join(DIR, stored))) throw new Error('Output file not found');
    const ext = path.extname(stored);
    const base = (process.env.PUBLIC_URL || `http://${req.headers.host}`).replace(/\/$/, '');
    const safeTitle = (title || 'flixgo').replace(/[\\/:*?"<>|\x00-\x1F]/g, '_').slice(0, 80);
    send(res, 200, { downloadUrl: `${base}/files/${stored}`, fileName: `${safeTitle}${ext}` });
  } catch (e) {
    send(res, 502, { error: e.message });
  } finally {
    jobs--;
  }
}

function handleFile(req, res) {
  const name = decodeURIComponent(req.url.split('?')[0].slice('/files/'.length));
  if (!/^[a-f0-9]{16}\.[a-z0-9]{2,4}$/.test(name)) return send(res, 404, { error: 'Not found' });
  const file = path.join(DIR, name);
  fs.stat(file, (err, st) => {
    if (err) return send(res, 404, { error: 'Not found' });
    res.writeHead(200, { 'Content-Type': TYPES[name.split('.').pop()] || 'application/octet-stream', 'Content-Length': st.size });
    fs.createReadStream(file).pipe(res);
  });
}

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/api/download') return handleDownload(req, res);
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
