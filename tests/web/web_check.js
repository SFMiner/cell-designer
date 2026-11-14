// Browser check of the real web export, driven by Playwright with the installed Google Chrome.
//
// 1. Copy the export to <root>/game/ and tests/web/harness.html to <root>/ (any folder outside the project).
// 2. Serve it:  python -m http.server 8791 --bind 127.0.0.1 --directory <root>   (check the port is free)
// 3. Run:       $env:NODE_PATH = "<game-sim-server>\node_modules"; $env:PORT = "8791"
//               node tests/web/web_check.js <folder for screenshots> [headed]
//    "headed" opens a visible Chrome window (real GPU); without it Chrome runs headless (software GL).
//    QUICK=1 shortens the 60 s no-input wait to 6 s.
// Exit code 0 only if every check passes. Screenshots are for a person to look at afterwards.
const { chromium } = require('playwright');
const shots = process.argv[2] || '.';
const headed = process.argv[3] === 'headed';
const port = process.env.PORT || '8791';
const base = 'http://127.0.0.1:' + port;
const idleMs = process.env.QUICK ? 6000 : 60000;

const results = [];
function check(ok, label) {
	results.push({ ok: !!ok, label });
	console.log((ok ? '  ok    ' : '  FAIL  ') + label);
}

(async () => {
	const launch = { channel: 'chrome', headless: !headed };
	if (!headed) {
		launch.args = ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'];
	}
	const browser = await chromium.launch(launch);
	console.log('browser: Google Chrome ' + browser.version() + (headed ? ' (headed window)' : ' (headless)'));

	async function open(context, url) {
		const page = await context.newPage();
		const logs = [];
		const requests = [];
		page.on('console', (m) => logs.push(m.text()));
		page.on('pageerror', (e) => logs.push('pageerror: ' + e.message));
		page.on('request', (r) => requests.push(r.url()));
		await page.goto(url);
		const waitLog = async (text, ms = 30000) => {
			const end = Date.now() + ms;
			while (Date.now() < end) {
				if (logs.some((l) => l.includes(text))) return true;
				await page.waitForTimeout(100);
			}
			return false;
		};
		const count = (text) => logs.filter((l) => l.includes(text)).length;
		return { page, logs, requests, waitLog, count };
	}
	const key = async (page, k, n = 1) => {
		for (let i = 0; i < n; i++) { await page.keyboard.press(k); await page.waitForTimeout(200); }
	};
	const same = (a, b) => Buffer.compare(a, b) === 0;
	const badLogs = (logs) => logs.filter((l) => /SCRIPT ERROR|pageerror|Parse Error|USER ERROR|^ERROR/.test(l));

	// ---------- 1. Standalone tab, 1180x500 ----------
	console.log('standalone 1180x500');
	let ctx = await browser.newContext({ viewport: { width: 1180, height: 500 } });
	let s = await open(ctx, base + '/game/index.html');
	check(await s.waitLog('cell-designer: boot ok'), 'standalone: console shows "cell-designer: boot ok"');
	check(s.count('level 1 ready (ATP particles on)') === 1, 'standalone: defaults are level 1, ATP particles on');
	await s.page.waitForTimeout(1500);
	const idleA = await s.page.screenshot({ path: shots + '/web_standalone_idle_start.png' });
	await s.page.waitForTimeout(idleMs);
	const idleB = await s.page.screenshot({ path: shots + '/web_standalone_idle_end.png' });
	check(same(idleA, idleB), 'no auto-play: frame is pixel-identical after ' + (idleMs / 1000) + ' s without input');
	check(s.count('started level') === 0, 'no auto-play: the level did not start by itself');
	// Keyboard Start, Escape for the call-outs, then a mouse click on the mitochondrion.
	await s.page.mouse.click(1100, 20); // empty reserved corner: focuses the canvas, presses nothing
	await key(s.page, 'Tab');
	await key(s.page, 'Enter');
	check(await s.waitLog('started level 1', 3000), 'standalone: Tab then Enter presses Start');
	check(await s.waitLog('callout l1_respiration', 8000), 'standalone: first tutorial call-out appears');
	await s.page.waitForTimeout(900);
	await s.page.screenshot({ path: shots + '/web_standalone_callout.png' });
	await key(s.page, 'Escape');
	check(await s.waitLog('callout l1_divide', 8000), 'standalone: second call-out appears after the first is closed');
	await s.page.waitForTimeout(900);
	await key(s.page, 'Escape');
	await s.page.mouse.click(728, 282); // the single mitochondrion sits at the centre of the cell view
	check(await s.waitLog('callout l1_ring', 4000), 'standalone: a mouse click on the mitochondrion divides it');
	await s.page.waitForTimeout(900);
	await key(s.page, 'Escape');
	await s.page.waitForTimeout(1200);
	await s.page.screenshot({ path: shots + '/web_standalone_playing.png' });
	check(badLogs(s.logs).length === 0, 'standalone: no SCRIPT ERROR or page error in the console (' + badLogs(s.logs).length + ')');
	// data: and blob: URLs are made inside the page and never touch the network.
	const foreign = s.requests.filter((u) => !u.startsWith(base) && !u.startsWith('data:') && !u.startsWith('blob:'));
	console.log('  requests: ' + s.requests.map((u) => u.length > 70 ? u.slice(0, 70) + '...' : u).join(' | '));
	check(foreign.length === 0, 'standalone: every network request stays on the game\'s own origin (' + s.requests.length + ' requests, ' + foreign.length + ' elsewhere)');
	await ctx.close();

	// ---------- 2. Class settings in the address ----------
	console.log('class settings');
	ctx = await browser.newContext({ viewport: { width: 1180, height: 500 } });
	s = await open(ctx, base + '/game/index.html?level=3&particles=off');
	check(await s.waitLog('level 3 ready (ATP particles off)'), 'query: ?level=3&particles=off opens level 3 with ATP particles off');
	await s.page.waitForTimeout(800);
	await s.page.screenshot({ path: shots + '/web_query_level3.png' });
	await s.page.close();
	s = await open(ctx, base + '/game/index.html?level=9&particles=maybe&debug=1');
	check(await s.waitLog('level 1 ready (ATP particles on)'), 'query: out-of-range and unknown values fall back to the defaults');
	await ctx.close();

	// ---------- 3. Same-origin iframe, 1180x500: keyboard walk-through ----------
	console.log('iframe 1180x500, keyboard only');
	ctx = await browser.newContext({ viewport: { width: 1240, height: 620 } });
	s = await open(ctx, base + '/harness.html');
	const leaves = () => s.page.evaluate(() => window.leaves);
	const active = () => s.page.evaluate(() => document.activeElement && document.activeElement.id);
	const frame = () => s.page.frames().find((f) => f.url().includes('/game/'));
	const clickEmpty = async () => { await frame().click('canvas', { position: { x: 1100, y: 20 } }); await s.page.waitForTimeout(250); };
	check(await s.waitLog('cell-designer: boot ok'), 'iframe: console shows "cell-designer: boot ok"');
	await s.page.waitForTimeout(1000);
	await s.page.screenshot({ path: shots + '/web_iframe_1180x500_start.png' });
	await clickEmpty();
	await key(s.page, 'Tab');
	await s.page.screenshot({ path: shots + '/web_iframe_focus_start.png' });
	await key(s.page, 'Enter');
	check(await s.waitLog('started level 1', 3000), 'iframe: Tab lands on Start and Enter starts the level');
	check(await s.waitLog('callout l1_respiration', 8000), 'iframe: tutorial call-out appears');
	await s.page.waitForTimeout(900);
	await key(s.page, 'Escape');
	await s.page.waitForTimeout(300);
	check((await leaves()) === 0, 'iframe: Escape with a call-out open closes the call-out and does not leave');
	check(await s.waitLog('callout l1_divide', 8000), 'iframe: the level resumed (next call-out arrived)');
	await s.page.waitForTimeout(900);
	await key(s.page, 'Escape');
	check((await leaves()) === 0, 'iframe: still inside the game after closing the second call-out');
	// Ring is now: Pause, Speed, Restart, Help, Settings, mitochondrion. Nothing is focused.
	await key(s.page, 'Tab', 6);
	await s.page.screenshot({ path: shots + '/web_iframe_focus_organelle.png' });
	await key(s.page, 'Enter');
	check(await s.waitLog('callout l1_ring', 4000), 'iframe: Tab reaches the mitochondrion and Enter divides it');
	await s.page.waitForTimeout(900);
	await key(s.page, 'Escape');
	await s.page.waitForTimeout(300);
	check((await leaves()) === 0, 'iframe: no leave message so far');
	// Focus is back on a daughter (new organelles are in the ring). One or two Tabs pass the last control.
	let before = await leaves();
	await key(s.page, 'Tab');
	if ((await leaves()) === before) { await key(s.page, 'Tab'); }
	check((await leaves()) === before + 1, 'iframe: Tab past the last organelle sends exactly one sims:leave-game');
	check((await active()) === 'fs', 'iframe: focus lands on the host page\'s Full screen button');
	// Shift+Tab before the first control.
	await clickEmpty();
	await key(s.page, 'Tab');
	before = await leaves();
	await key(s.page, 'Shift+Tab');
	check((await leaves()) === before + 1 && (await active()) === 'fs', 'iframe: Shift+Tab before the first control leaves to the host');
	// Escape with nothing open.
	await clickEmpty();
	before = await leaves();
	await key(s.page, 'Escape');
	check((await leaves()) === before + 1 && (await active()) === 'fs', 'iframe: Escape with nothing open leaves to the host');
	// Pause really freezes the picture; resuming moves it again.
	await clickEmpty();
	await key(s.page, 'Tab');
	await key(s.page, 'Enter');
	await s.page.waitForTimeout(500);
	const pausedA = await s.page.screenshot({ path: shots + '/web_iframe_paused.png' });
	await s.page.waitForTimeout(4000);
	const pausedB = await s.page.screenshot();
	check(same(pausedA, pausedB), 'iframe: Pause freezes the whole frame for 4 s (pixel-identical)');
	before = await leaves();
	await key(s.page, 'Escape');
	check((await leaves()) === before, 'iframe: Escape closes Pause without leaving');
	const running = [];
	for (let i = 0; i < 4; i++) { await s.page.waitForTimeout(700); running.push(await s.page.screenshot()); }
	check(!running.every((b) => same(b, running[0])), 'iframe: after resuming, the picture changes again');
	check(badLogs(s.logs).length === 0, 'iframe: no SCRIPT ERROR or page error in the console (' + badLogs(s.logs).length + ')');
	await ctx.close();

	// ---------- 4. Other frame sizes (screenshots to inspect; boot and errors checked) ----------
	const variants = [
		{ name: 'iframe_1180x360', w: 1180, h: 360, dpr: 1, q: 'level=3' },
		{ name: 'iframe_dpr1_5', w: 1180, h: 500, dpr: 1.5, q: 'level=2' },
		{ name: 'iframe_zoom200_emulated', w: 590, h: 250, dpr: 2, q: 'level=1' },
		{ name: 'iframe_phone_like_380x640', w: 380, h: 640, dpr: 2, q: 'level=3' },
	];
	for (const v of variants) {
		console.log(v.name);
		ctx = await browser.newContext({ viewport: { width: v.w + 60, height: v.h + 120 }, deviceScaleFactor: v.dpr });
		s = await open(ctx, base + '/harness.html?w=' + v.w + '&h=' + v.h + '&q=' + encodeURIComponent(v.q));
		check(await s.waitLog('cell-designer: boot ok'), v.name + ': boots');
		await s.page.waitForTimeout(1200);
		await s.page.screenshot({ path: shots + '/web_' + v.name + '_start.png' });
		const f = s.page.frames().find((fr) => fr.url().includes('/game/'));
		await f.click('canvas', { position: { x: v.w - 30, y: 12 } });
		await key(s.page, 'Tab');
		await key(s.page, 'Enter');
		check(await s.waitLog('started level', 3000), v.name + ': starts from the keyboard');
		await s.page.waitForTimeout(2500);
		await s.page.screenshot({ path: shots + '/web_' + v.name + '_playing.png' });
		// Resize the frame while it runs: the layout must follow.
		await s.page.evaluate(() => { const g = document.getElementById('g'); g.width = String(Math.round(g.width * 0.8)); });
		await s.page.waitForTimeout(800);
		await s.page.screenshot({ path: shots + '/web_' + v.name + '_resized.png' });
		check(badLogs(s.logs).length === 0, v.name + ': no SCRIPT ERROR or page error');
		await ctx.close();
	}

	await browser.close();
	const failed = results.filter((r) => !r.ok).length;
	console.log('WEB CHECK: ' + (results.length - failed) + '/' + results.length + ' passed -> ' + (failed === 0 ? 'PASS' : 'FAIL'));
	process.exit(failed === 0 ? 0 : 1);
})().catch((e) => { console.error(e); process.exit(2); });
