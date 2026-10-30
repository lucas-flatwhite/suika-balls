/* Exercise real Node responses using the deployment's filesystem-first fallback. */
const assert = require('node:assert/strict');
const {createServer} = require('node:http');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const missingRelease = require('../api/release-not-found');
const config = JSON.parse(readFileSync(join(__dirname, '../vercel.json'), 'utf8'));
const rule = config.rewrites.find(rule => rule.source === '/releases/:path*');
assert.equal(rule.destination, '/api/release-not-found');
const existing = '/releases/01234567890123456789/index.wasm';
const server = createServer((req, res) => {
  // Vercel serves existing filesystem paths before applying a fallback rewrite.
  if (req.url === existing) {
    const cache = config.headers.find(rule => rule.source === '/releases/:path*').headers.find(header => header.key === 'Cache-Control').value;
    res.writeHead(200, {'Content-Type':'application/wasm','Cache-Control':cache});
    res.end('wasm-fixture');
  } else {
    // Config headers can already be present; the error response must replace them.
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    missingRelease(req, res);
  }
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    const success = await fetch(base+existing);
    assert.equal(success.status,200);
    assert.match(success.headers.get('cache-control'),/31536000.*immutable/);
    for (const path of ['/releases/01234567890123456789/missing.wasm','/releases/missing-version/index.pck','/api/release-not-found']) {
      for (const method of ['GET','HEAD']) {
        const response = await fetch(base+path,{method});
        assert.equal(response.status,404);
        assert.equal(response.headers.get('cache-control'),'no-store');
        assert.equal(response.headers.get('cdn-cache-control'),'no-store');
        if (method==='HEAD') assert.equal(await response.text(),'');
      }
    }
    console.log('PASS: existing release is immutable; missing file/version and direct error GET/HEAD return no-store 404');
  } finally { server.close(); }
})().catch(error => {console.error(error); process.exitCode=1;});
