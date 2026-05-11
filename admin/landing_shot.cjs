const { chromium, devices } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const url = 'https://growtogether.kr/';
  const viewports = [
    { name: 'mobile-320', width: 320, height: 700 },
    { name: 'mobile-336', width: 336, height: 813 },
    { name: 'mobile-360', width: 360, height: 740 },
    { name: 'mobile-iphone14', ...devices['iPhone 14'].viewport },
    { name: 'tablet-768', width: 768, height: 1024 },
    { name: 'desktop-1440', width: 1440, height: 900 },
  ];
  for (const vp of viewports) {
    const ctx = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      deviceScaleFactor: 2,
    });
    const page = await ctx.newPage();
    await page.goto(url, { waitUntil: 'networkidle' });
    await page.addStyleTag({ content: `.reveal, .reveal.d1, .reveal.d2, .reveal.d3 { opacity:1!important; transform:none!important; transition:none!important; }` });
    await page.waitForTimeout(400);
    // 가로 overflow 측정
    const ow = await page.evaluate(() => ({
      docW: document.documentElement.scrollWidth,
      bodyW: document.body.scrollWidth,
      vpW: window.innerWidth,
    }));
    console.log(`${vp.name} ${vp.width}x${vp.height} -> docW=${ow.docW} bodyW=${ow.bodyW} vpW=${ow.vpW} overflow=${ow.docW - ow.vpW}px`);
    await page.screenshot({ path: `/tmp/landing_${vp.name}.png`, fullPage: true });
    await ctx.close();
  }
  await browser.close();
})();
