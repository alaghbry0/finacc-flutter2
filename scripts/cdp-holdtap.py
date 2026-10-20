#!/usr/bin/env python3
"""نقرة لمسية بمدة ضغط — لحل نزاع حلبة الإيماءات داخل القوائم القابلة للتمرير.

الاستخدام:
  python3 cdp-holdtap.py <x> <y> [hold_ms]
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


async def holdtap(ws, x, y, hold_ms):
    x, y = float(x), float(y)
    pt = {'x': x, 'y': y}
    r1 = await send(ws, 'Input.dispatchTouchEvent', {
        'type': 'touchStart', 'touchPoints': [pt]})
    await asyncio.sleep(float(hold_ms) / 1000)
    r2 = await send(ws, 'Input.dispatchTouchEvent', {
        'type': 'touchEnd', 'touchPoints': []})
    ok = 'error' not in r1 and 'error' not in r2
    print('HOLDTAP', 'OK' if ok else f'ERR {r1.get("error")} {r2.get("error")}')


async def main():
    x, y = sys.argv[1], sys.argv[2]
    hold_ms = sys.argv[3] if len(sys.argv) > 3 else '120'
    ws_url = await page_ws()
    async with websockets.connect(ws_url, max_size=10 ** 7) as ws:
        await holdtap(ws, x, y, hold_ms)

asyncio.run(main())
