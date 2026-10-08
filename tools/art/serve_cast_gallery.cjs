// Local preview of the cast reference gallery. Serves only the concept folder.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../../assets/art/reference/cast_redesign_v1');
const port = Number(process.env.CAST_GALLERY_PORT || 8964);
const types = { '.html': 'text/html; charset=utf-8', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { Allow: 'GET, HEAD' });
    return res.end();
  }
  let name;
  try { name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); }
  catch { res.writeHead(400); return res.end(); }
  if (name === '/') name = '/gallery.html';
  const file = path.resolve(root, '.' + name);
  const extension = path.extname(file).toLowerCase();
  if (!file.startsWith(root + path.sep) || !types[extension]) {
    res.writeHead(404);
    return res.end();
  }
  fs.stat(file, (error, stat) => {
    if (error || !stat.isFile()) { res.writeHead(404); return res.end(); }
    res.writeHead(200, {
      'Content-Type': types[extension], 'Content-Length': stat.size,
      'Cache-Control': 'no-cache', 'X-Content-Type-Options': 'nosniff',
    });
    if (req.method === 'HEAD') return res.end();
    const stream = fs.createReadStream(file);
    stream.on('error', () => res.destroy());
    stream.pipe(res);
  });
});
server.listen(port, '127.0.0.1', () => console.log(`Cast gallery: http://127.0.0.1:${port}/`));
server.on('error', error => { console.error(error.message); process.exitCode = 1; });
