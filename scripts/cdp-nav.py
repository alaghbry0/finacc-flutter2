#!/usr/bin/env python3
"""مساعد CDP للتنقل واللقطات — يفتح :81 ويلتقط PNG بالحجم الكامل.

الاستخدام:
  python3 cdp-nav.py open <url>        # فتح/تنقل الصفحة النشطة
  python3 cdp-nav.py shot <file.png>   # لقطة الشاشة الحالية
  python3 cdp-nav.py eval <js>         # تنفيذ JavaScript وإرجاع النتيجة
"""
import asyncio
import base64
import json
import os
import sys

import websockets

CDP_HTTP = f"http://127.0.0.1:{os.environ.get('CDP_PORT', '44977')}"
PAGE_MATCH = os.environ.get('CDP_PAGE_MATCH', 'about:blank')

_id = 0


async def page_ws():
    import urllib.request
    with urllib.request.urlopen(f'{CDP_HTTP}/json') as r:
        targets = json.loads(r.read())
    for t in targets:
        if t.get('type') == 'page' and PAGE_MATCH in t.get('url', ''):
            return t['webSocketDebuggerUrl']
    raise SystemExit('NO_PAGE_TARGET')


async def send(ws, method, params=None):
    global _id
    _id += 1
    msg = {'id': _id, 'method': method, 'params': params or {}}
    await ws.send(json.dumps(msg))
    while True:
        raw = await ws.recv()
        data = json.loads(raw)
        if data.get('id') == _id:
            return data


async def main():
    cmd = sys.argv[1]
    async with websockets.connect(await page_ws(), max_size=64 * 1024 * 1024) as ws:
        if cmd == 'open':
            url = sys.argv[2]
            r = await send(ws, 'Page.navigate', {'url': url})
            print('NAV', r.get('result', {}).get('frameId', r.get('error', '?')))
        elif cmd == 'shot':
            out = sys.argv[2]
            r = await send(ws, 'Page.captureScreenshot', {'format': 'png'})
            data = r.get('result', {}).get('data')
            if data:
                with open(out, 'wb') as f:
                    f.write(base64.b64decode(data))
                print('SHOT', out, len(data) * 3 // 4, 'bytes')
            else:
                print('ERR', r.get('error'))
        elif cmd == 'eval':
            js = sys.argv[2]
            r = await send(ws, 'Runtime.evaluate', {
                'expression': js, 'returnByValue': True})
            print(json.dumps(r.get('result', {}).get('result', {}).get('value',
                  r.get('result', {}).get('exceptionDetails', '?')),
                  ensure_ascii=False))
        elif cmd == 'size':
            w, h = int(sys.argv[2]), int(sys.argv[3])
            await send(ws, 'Emulation.setDeviceMetricsOverride', {
                'width': w, 'height': h, 'deviceScaleFactor': 1.0,
                'mobile': True})
            print('SIZE', w, h)


asyncio.run(main())
