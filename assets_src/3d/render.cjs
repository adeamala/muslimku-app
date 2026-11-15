#!/usr/bin/env node
/*
 * Renders the Muslimku "Diorama Senja" 3D art (gen3d.html, three.js) in headless
 * Chromium and writes trimmed WebP files to images/3d/.
 *
 *   cd assets_src/3d
 *   npm install --no-save three@0.180.0 playwright-core
 *   CHROMIUM_PATH=/usr/bin/chromium-browser node render.cjs
 */
'use strict';
const path = require('path');
const fs = require('fs');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright-core');

const OUT = path.resolve(__dirname, '../../images/3d');

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || undefined,
    args: ['--allow-file-access-from-files', '--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--ignore-gpu-blocklist'],
  });
  const page = await browser.newPage({ viewport: { width: 1300, height: 1300 } });
  const problems = [];
  page.on('pageerror', (e) => problems.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') problems.push(m.text()); });
  // ONLY=kalender,catatan renders just those assets (file names without `icon_`/`.webp`).
  const only = process.env.ONLY ? process.env.ONLY.split(',') : null;
  await page.goto('file://' + path.join(__dirname, 'gen3d.html') + (only ? '?only=' + only.join(',') : ''));
  await page.waitForFunction(() => document.body.dataset.ready === '1', null, { timeout: 300000 });
  const assets = await page.evaluate(() => window.__assets);
  for (const [name, a] of Object.entries(assets)) {
    if (only && !only.includes(name.replace(/^icon_/, ''))) continue;
    const file = path.join(OUT, name + '.webp');
    fs.writeFileSync(file, Buffer.from(a.url.split(',')[1], 'base64'));
    console.log(`${name}.webp ${a.w}x${a.h} ${fs.statSync(file).size} B`);
  }
  await browser.close();
  if (problems.length) { console.error(problems.join('\n')); process.exit(1); }
})().catch((e) => { console.error(e); process.exit(1); });
