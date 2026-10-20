#!/usr/bin/env python3
"""كتابة نص حرفًا حرفًا عبر أحداث لوحة المفاتيح CDP.

مختلف عن insertText: يمر عبر معالج لوحة المفاتيح في Flutter فيُحدّث
TextEditingController بشكل موثوق (مثل الكتابة الحقيقية).

الاستخدام:
  python3 cdp-type.py "النص هنا"
"""
import asyncio
import json
import sys

import websockets

import os
CDP_HTTP = f"http://127.0.0.1:{os.environ.get('CDP_PORT', '44977')}"
PAGE_MATCH = os.environ.get('CDP_PAGE_MATCH', ':81')

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


async def type_text(ws, text):
    ok = True
    for ch in text:
        r1 = await send(ws, 'Input.dispatchKeyEvent', {
            'type': 'keyDown',
            'key': ch,
            'text': ch,
            'unmodifiedText': ch,
        })
        if 'error' in r1:
            ok = False
            print('KEYDOWN ERR', r1.get('error'))
            break
        r2 = await send(ws, 'Input.dispatchKeyEvent', {
            'type': 'keyUp',
            'key': ch,
        })
        if 'error' in r2:
            ok = False
            print('KEYUP ERR', r2.get('error'))
            break
        await asyncio.sleep(0.035)
    print('TYPE', 'OK' if ok else 'ERR')


async def main():
    ws_url = await page_ws()
    async with websockets.connect(ws_url, max_size=10 ** 7) as ws:
        await type_text(ws, sys.argv[1])

asyncio.run(main())
