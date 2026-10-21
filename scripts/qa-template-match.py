#!/usr/bin/env python3
"""مطابقة قالبية NCC — يرندر نصًا عربيًا بخط Cairo ويطابقه في لقطة شاشة.

الاستخدام: python3 scripts/qa-template-match.py <screenshot> <text> [font_size_logical]
يطبع أفضل موضع ومقياس ومعامل الارتباط NCC.
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

CAIRO = '/home/z/my-project/mobile_app/assets/fonts/cairo/Cairo-Regular.ttf'


def render(text: str, size_px: int) -> Image.Image:
    font = ImageFont.truetype(CAIRO, size_px)
    pad = size_px // 2
    tmp = Image.new('L', (8, 8), 0)
    d = ImageDraw.Draw(tmp)
    box = d.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0] + pad * 2, box[3] - box[1] + pad * 2
    img = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(img)
    d.text((pad - box[0], pad - box[1]), text, font=font, fill=255)
    return img


def ncc(a: np.ndarray, b: np.ndarray) -> float:
    a = a.astype(np.float64) - a.mean()
    b = b.astype(np.float64) - b.mean()
    den = np.sqrt((a * a).sum() * (b * b).sum())
    return float((a * b).sum() / den) if den > 0 else 0.0


def main() -> None:
    shot_path, text = sys.argv[1], sys.argv[2]
    size_logical = int(sys.argv[3]) if len(sys.argv) > 3 else 12
    shot = Image.open(shot_path).convert('L')
    S = np.array(shot)

    best = (0.0, None, None)
    for dpr in (2.0, 1.9, 2.1):
        size_px = int(round(size_logical * dpr))
        tpl = np.array(render(text, size_px))
        th, tw = tpl.shape
        if th < 2 or tw < 2 or S.shape[0] < th or S.shape[1] < tw:
            continue
        # استراتيجية: عتبة القالب (النص داكن على فاتح) — نطابق تدرج الرمادي
        step = max(1, min(S.shape[0] - th, S.shape[1] - tw) // 800)
        for y in range(0, S.shape[0] - th, max(1, step * 4)):
            for x in range(0, S.shape[1] - tw, max(1, step * 2)):
                patch = S[y:y + th, x:x + tw]
                inv = 255 - patch
                score = ncc(tpl, inv)
                if score > best[0]:
                    best = (score, (x, y, tw, th), dpr)
    score, box, dpr = best
    if box:
        print(f'BEST NCC={score:.3f} box={box} dpr={dpr} center=({(box[0]+box[2]//2)/2:.0f},{(box[1]+box[3]//2)/2:.0f}) CSS')
    else:
        print('NO MATCH')
    print('VERDICT:', 'MATCH' if score > 0.55 else 'WEAK' if score > 0.4 else 'NOT FOUND')


if __name__ == '__main__':
    main()
