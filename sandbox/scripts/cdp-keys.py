#!/usr/bin/env python3
"""إرسال أحرف بأحداث مفاتيح CDP كاملة (مع text وcode)."""
import asyncio, json, sys, os
import websockets

CDP_HTTP = f"http://127.0.0.1:{os.environ.get('CDP_PORT', '35161')}"

async def main():
    text = sys.argv[1]
    import urllib.request
    with urllib.request.urlopen(f'{CDP_HTTP}/json') as r:
        targets = json.loads(r.read())
    ws_url = next(t['webSocketDebuggerUrl'] for t in targets
                  if t.get('type') == 'page' and 'mobile_app' in t.get('url', ''))
    _id = 0
    async with websockets.connect(ws_url, max_size=10**7) as ws:
        async def send(method, params):
            nonlocal _id
            _id += 1
            await ws.send(json.dumps({'id': _id, 'method': method, 'params': params}))
            while True:
                data = json.loads(await ws.recv())
                if data.get('id') == _id:
                    return data
        for ch in text:
            vk = ord(ch.upper()) if ch.isalnum() else 0
            code = f'Key{ch.upper()}' if ch.isalpha() else (f'Digit{ch}' if ch.isdigit() else 'Space' if ch == ' ' else None)
            p = {'type': 'keyDown', 'key': ch, 'text': ch}
            if code: p['code'] = code
            if vk: p['windowsVirtualKeyCode'] = vk
            r1 = await send('Input.dispatchKeyEvent', p)
            r2 = await send('Input.dispatchKeyEvent', {'type': 'keyUp', 'key': ch, **({'code': code} if code else {}), **({'windowsVirtualKeyCode': vk} if vk else {})})
            if 'error' in r1 or 'error' in r2:
                print('ERR', r1.get('error'), r2.get('error')); return
        print('KEYS OK:', text)

asyncio.run(main())
