#!/usr/bin/env python3
"""مساعد CDP — أحداث لمس/إدخال موثوقة لتطبيق Flutter Web.

الاستخدام:
  python3 cdp-touch.py tap <x> <y>              # نقرة لمس واحدة
  python3 cdp-touch.py insert <text>            # إدخال نص للعنصر المركّز
  python3 cdp-touch.py key <key>                # ضغطة مفتاح (Enter/Tab/...)
  python3 cdp-touch.py swipe <x1> <y1> <x2> <y2> [ms]  # سحب
"""
import asyncio
import json
import sys

import websockets

import os
CDP_HTTP = f"http://127.0.0.1:{os.environ.get('CDP_PORT', '44977')}"
PAGE_MATCH = 'mobile_app'

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


async def tap(ws, x, y):
    x, y = float(x), float(y)
    pt = {'x': x, 'y': y}
    r1 = await send(ws, 'Input.dispatchTouchEvent', {
        'type': 'touchStart', 'touchPoints': [pt]})
    r2 = await send(ws, 'Input.dispatchTouchEvent', {
        'type': 'touchEnd', 'touchPoints': []})
    ok = 'error' not in r1 and 'error' not in r2
    print('TAP', 'OK' if ok else f'ERR {r1.get("error")} {r2.get("error")}')


async def insert(ws, text):
    r = await send(ws, 'Input.insertText', {'text': text})
    print('INSERT', 'OK' if 'error' not in r else f'ERR {r.get("error")}')


async def key(ws, k):
    defs = [
        {'type': 'keyDown', 'key': k},
        {'type': 'keyUp', 'key': k},
    ]
    for d in defs:
        r = await send(ws, 'Input.dispatchKeyEvent', d)
        if 'error' in r:
            print('KEY ERR', r.get('error'))
            return
    print('KEY OK')


async def swipe(ws, x1, y1, x2, y2, ms=300):
    x1, y1, x2, y2 = map(float, (x1, y1, x2, y2))
    steps = 12
    await send(ws, 'Input.dispatchTouchEvent', {
        'type': 'touchStart',
        'touchPoints': [{'x': x1, 'y': y1}]})
    for i in range(1, steps + 1):
        x = x1 + (x2 - x1) * i / steps
        y = y1 + (y2 - y1) * i / steps
        await send(ws, 'Input.dispatchTouchEvent', {
            'type': 'touchMove',
            'touchPoints': [{'x': x, 'y': y}]})
        await asyncio.sleep(float(ms) / 1000 / steps)
    await send(ws, 'Input.dispatchTouchEvent', {
        'type': 'touchEnd', 'touchPoints': []})
    print('SWIPE OK')


async def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    ws_url = await page_ws()
    async with websockets.connect(ws_url, max_size=10 ** 7) as ws:
        if cmd == 'tap':
            await tap(ws, sys.argv[2], sys.argv[3])
        elif cmd == 'insert':
            await insert(ws, sys.argv[2])
        elif cmd == 'key':
            await key(ws, sys.argv[2])
        elif cmd == 'swipe':
            ms = sys.argv[6] if len(sys.argv) > 6 else '300'
            await swipe(ws, *sys.argv[2:6], ms)
        else:
            print(__doc__)


asyncio.run(main())
