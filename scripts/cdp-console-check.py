#!/usr/bin/env python3
"""فحص أخطاء الكونسول — يعيد تحميل الصفحة ويلتقط استثناءات/أخطاء JS لمدة محددة.

الاستخدام: python3 cdp-console-check.py <seconds>
"""
import asyncio
import json
import os
import sys

import websockets

CDP_HTTP = f"http://127.0.0.1:{os.environ.get('CDP_PORT', '44977')}"
PAGE_MATCH = os.environ.get('CDP_PAGE_MATCH', '127.0.0.1:3000')

_id = 0
_errors = []


async def page_ws():
    import urllib.request
    with urllib.request.urlopen(f'{CDP_HTTP}/json') as r:
        targets = json.loads(r.read())
    for t in targets:
        if t.get('type') == 'page' and PAGE_MATCH in t.get('url', ''):
            return t['webSocketDebuggerUrl']
    raise SystemExit('NO_PAGE_TARGET')


async def main():
    seconds = float(sys.argv[1]) if len(sys.argv) > 1 else 15.0
    async with websockets.connect(await page_ws(), max_size=64 * 1024 * 1024) as ws:
        global _id

        async def send(method, params=None):
            global _id
            _id += 1
            msg = {'id': _id, 'method': method, 'params': params or {}}
            await ws.send(json.dumps(msg))

        await send('Runtime.enable')
        await send('Log.enable')
        await send('Page.enable')
        await send('Page.reload', {'ignoreCache': True})

        async def pump(duration):
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=duration)
            except asyncio.TimeoutError:
                return
            data = json.loads(raw)
            m = data.get('method', '')
            if m == 'Runtime.exceptionThrown':
                d = data['params']['exceptionDetails']
                txt = d.get('exception', {}).get('description') or d.get('text', '')
                _errors.append('EXCEPTION: ' + txt[:300])
            elif m == 'Log.entryAdded':
                e = data['params']['entry']
                if e.get('level') in ('error', 'warning') and 'favicon' not in str(e.get('url', '')):
                    _errors.append(f"{e['level'].upper()}: {e.get('text', '')[:300]}")
            elif m == 'Runtime.consoleAPICalled':
                if data['params'].get('type') == 'error':
                    args = ' '.join(str(a.get('value', '')) for a in data['params'].get('args', []))
                    _errors.append('CONSOLE.error: ' + args[:300])

        deadline = asyncio.get_event_loop().time() + seconds
        while asyncio.get_event_loop().time() < deadline:
            remaining = deadline - asyncio.get_event_loop().time()
            await pump(max(0.5, min(2.0, remaining)))

    if _errors:
        print(f'{len(_errors)} issue(s):')
        for e in _errors[:20]:
            print(' -', e)
    else:
        print('CLEAN — zero console errors/exceptions')
    await asyncio.sleep(0)


asyncio.run(main())
