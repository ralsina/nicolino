// Capture full-page screenshots of every theme demo.
//
// The demos must be built first (scripts/build-theme-demos.sh or
// `make theme-demos`) so that assets/themes/demo/<theme>/ exists.
// Outputs assets/themes/shots/<theme>.png, which the site serves at
// /themes/shots/<theme>.png.
//
// Requires: Node + the `playwright` npm package and its Firefox build
//   npm install playwright && npx playwright install firefox
//
// Usage:  node scripts/screenshot-themes.js
const { firefox } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const REPO = path.join(__dirname, '..');
const ASSETS = path.join(REPO, 'assets');
const THEMES = ['default', 'minimal', 'terminal', 'papermod', 'blox'];
const VIEWPORT_WIDTH = 1280;
const OUT_DIR = path.join(ASSETS, 'themes', 'shots');

const MIME = {
  '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.gif': 'image/gif', '.svg': 'image/svg+xml', '.webp': 'image/webp',
  '.xml': 'application/xml', '.ico': 'image/x-icon', '.json': 'application/json',
};

function serve(req, res) {
  const urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  let rel = urlPath.replace(/^\/+/, '');
  if (rel === '' || rel.endsWith('/')) rel += 'index.html';
  const filePath = path.join(ASSETS, rel);
  if (!filePath.startsWith(ASSETS)) { res.writeHead(403).end(); return; }
  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end('not found'); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(filePath).toLowerCase()] || 'application/octet-stream' });
    res.end(data);
  });
}

(async () => {
  const httpServer = http.createServer(serve);
  await new Promise((r) => httpServer.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${httpServer.address().port}/themes/demo`;
  console.log(`Serving demos on port ${httpServer.address().port}`);

  fs.mkdirSync(OUT_DIR, { recursive: true });

  const browser = await firefox.launch();
  const page = await browser.newPage({ viewport: { width: VIEWPORT_WIDTH, height: 900 } });

  for (const theme of THEMES) {
    const url = `${base}/${theme}/`;
    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 20000 });
      await page.waitForTimeout(500);
      const outPath = path.join(OUT_DIR, `${theme}.png`);
      await page.screenshot({ path: outPath, fullPage: true });
      const size = fs.statSync(outPath).size;
      console.log(`  ✓ ${theme} → ${path.relative(REPO, outPath)} (${(size / 1024).toFixed(1)} KiB)`);
    } catch (e) {
      console.error(`  ✗ ${theme}: ${e.message}`);
    }
  }

  await browser.close();
  await new Promise((r) => httpServer.close(r));
  console.log('Done.');
})().catch((e) => { console.error(e); process.exit(1); });
