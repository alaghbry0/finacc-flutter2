#!/usr/bin/env python3
"""OCR مع إحداثيات — يحلل لقطة شاشة ويعرض الكلمات العربية مع مواضعها.

الاستخدام: python3 scripts/ocr-boxes.py <screenshot> [word_filter]
"""
import subprocess
import sys


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/qa-nav.png"
    word_filter = sys.argv[2] if len(sys.argv) > 2 else None

    result = subprocess.run(
        [
            "tesseract", path, "stdout", "-l", "ara+eng", "--psm", "11",
            "tsv",
        ],
        capture_output=True, text=True,
        env={
            "TESSDATA_PREFIX": "/tmp/tessdata-test",
            "PATH": "/usr/bin:/bin",
        },
    )

    lines = result.stdout.splitlines()
    header = lines[0].split("\t")
    idx = {name: i for i, name in enumerate(header)}

    words = []
    for line in lines[1:]:
        cols = line.split("\t")
        if len(cols) < 12:
            continue
        text = cols[idx["text"]].strip()
        conf = float(cols[idx["conf"]])
        if not text or conf < 40:
            continue
        x, y, w, h = (
            int(cols[idx["left"]]),
            int(cols[idx["top"]]),
            int(cols[idx["width"]]),
            int(cols[idx["height"]]),
        )
        words.append((text, x, y, w, h, conf))

    if word_filter:
        words = [wd for wd in words if word_filter in wd[0]]

    for text, x, y, w, h, conf in words:
        cx, cy = x + w // 2, y + h // 2
        print(f"{text!r:40s} center=({cx},{cy}) box=({x},{y},{w},{h}) conf={conf:.0f}")


if __name__ == "__main__":
    main()
