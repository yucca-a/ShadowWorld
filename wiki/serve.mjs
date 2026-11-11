import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('./dist/', import.meta.url));
const mime = { '.html':'text/html; charset=utf-8', '.css':'text/css; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.svg':'image/svg+xml', '.png':'image/png' };
const port = Number(process.env.WIKI_PORT || 4178);
http.createServer(async (req,res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    const filename = path.resolve(root, '.' + (pathname.endsWith('/') ? pathname + 'index.html' : pathname));
    if (!filename.startsWith(root)) { res.writeHead(403); return res.end('Forbidden'); }
    const data = await fs.readFile(filename);
    res.writeHead(200, { 'content-type': mime[path.extname(filename)] || 'application/octet-stream', 'cache-control':'no-store' });
    res.end(data);
  } catch { res.writeHead(404, { 'content-type':'text/plain; charset=utf-8' }); res.end('页面不存在'); }
}).listen(port, '127.0.0.1', () => console.log(`Local: http://127.0.0.1:${port}`));
