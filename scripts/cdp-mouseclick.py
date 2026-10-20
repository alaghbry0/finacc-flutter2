#!/usr/bin/env python3
"""نقرة فأرة CDP — لاختبار مسار إدخال بديل عن اللمس في Flutter Web.

الاستخدام:
  python3 cdp-mouseclick.py <x> <y>
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


async def mouseclick(ws, x, y):
    x, y = float(x), float(y)
    common = {'x': x, 'y': y, 'button': 'left', 'clickCount': 1}
    r1 = await send(ws, 'Input.dispatchMouseEvent', {
        'type': 'mousePressed', **common})
    await asyncio.sleep(0.05)
    r2 = await send(ws, 'Input.dispatchMouseEvent', {
        'type': 'mouseReleased', **common})
    ok = 'error' not in r1 and 'error' not in r2
    print('MOUSECLICK', 'OK' if ok else f'ERR {r1.get("error")} {r2.get("error")}')


async def main():
    ws_url = await page_ws()
    async with websockets.connect(ws_url, max_size=10 ** 7) as ws:
        await mouseclick(ws, sys.argv[1], sys.argv[2])

asyncio.run(main())
