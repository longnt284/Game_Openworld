// Browser smoke test for the web export: serves build/web, opens it in headless Chromium
// (software WebGL2), waits for the game to report VK_READY, starts a new game and checks
// that no script errors were logged. Screenshots go to .cache/web_smoke/.
//   node tools/web_smoke.cjs [--keep-open]
// Needs Playwright (global install is fine: NODE_PATH or /opt/node22/lib/node_modules).
const fs = require('fs');
const http = require('http');
const path = require('path');

function loadPlaywright() {
  const candidates = ['playwright', '/opt/node22/lib/node_modules/playwright'];
  for (const name of candidates) {
    try { return require(name); } catch (error) { /* try next */ }
  }
  throw new Error('Playwright not found; install it or set NODE_PATH');
}

const ROOT = path.resolve(__dirname, '..');
const WEB = path.join(ROOT, 'build', 'web');
const OUT = path.join(ROOT, '.cache', 'web_smoke');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

function serve() {
  return new Promise((resolve) => {
    const server = http.createServer((request, response) => {
      const name = decodeURIComponent(request.url.split('?')[0]);
      const file = path.join(WEB, name === '/' ? 'index.html' : name);
      if (!file.startsWith(WEB) || !fs.existsSync(file)) { response.writeHead(404); response.end(); return; }
      response.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
      fs.createReadStream(file).pipe(response);
    });
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

async function main() {
  if (!fs.existsSync(path.join(WEB, 'index.html'))) throw new Error('build/web missing; run tools/run.sh web first');
  fs.mkdirSync(OUT, { recursive: true });
  const { chromium } = loadPlaywright();
  const server = await serve();
  const url = `http://127.0.0.1:${server.address().port}/index.html${process.env.VK_QUERY || ''}`;
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  let ready = false;
  page.on('pageerror', (error) => errors.push('pageerror: ' + error.message));
  page.on('console', (message) => {
    const text = message.text();
    if (text.includes('VK_READY')) ready = true;
    if (/SCRIPT ERROR|Parse Error|Invalid call|Attempt to call/.test(text)) errors.push(text);
    if (process.env.VK_VERBOSE) console.log('[page]', text);
  });
  const started = Date.now();
  await page.goto(url);
  while (!ready && Date.now() - started < 240000) await page.waitForTimeout(500);
  if (!ready) errors.push('VK_READY not seen within 240 s');
  console.log(`title ready after ${((Date.now() - started) / 1000).toFixed(1)} s`);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT, 'title.png') });
  if (ready) {
    // Focus starts on "Hành trình mới"; a click on the canvas first gives the page a user gesture.
    await page.mouse.click(640, 700);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(25000);
    await page.screenshot({ path: path.join(OUT, 'play.png') });
    await page.keyboard.down('KeyW');
    await page.waitForTimeout(4000);
    await page.keyboard.up('KeyW');
    await page.screenshot({ path: path.join(OUT, 'walk.png') });
  }
  await browser.close();
  server.close();
  for (const error of errors) console.error('WEB SMOKE ERROR:', error);
  console.log(errors.length === 0 ? 'WEB SMOKE: PASS' : `WEB SMOKE: ${errors.length} error(s)`);
  process.exit(errors.length === 0 ? 0 : 1);
}

main().catch((error) => { console.error(error); process.exit(1); });
