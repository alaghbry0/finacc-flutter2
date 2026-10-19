#!/bin/bash
# تحليل لقطات شاشة Simple Invoice Manager لاستخراج مواصفات UI/UX
# الاستخدام: bash /home/z/my-project/scripts/analyze-screens.sh

UPLOAD=/home/z/my-project/upload
OUT=/home/z/my-project/upload/analysis
mkdir -p "$OUT"

PROMPT='You are a senior mobile UI/UX design analyst. Analyze this screenshot of the "Simple Invoice Manager" Android app (Arabic RTL interface) in EXTREME detail for pixel-perfect cloning. Describe:
1. Screen name/purpose and what user flow step it represents
2. Complete layout structure top-to-bottom: app bar (height, color, icons, titles), tabs, filters, search bars, list items, FABs, bottom nav
3. EXACT colors you observe (give hex estimates): primary blue, backgrounds, badges, text colors
4. Typography: sizes, weights, which text is bold
5. Every icon and its position (RTL aware - describe from right side)
6. List item structure: what fields, date column, client name, amounts, status badges (colors + text)
7. Any cards, chips, dropdowns, chips rows, month summary strips
8. Spacing patterns, borders, shadows, corner radius
9. Exact Arabic text visible (transcribe ALL Arabic labels precisely)
Be exhaustive - this analysis will be used as the authoritative spec to rebuild this screen in Flutter.'

for img in "$UPLOAD"/Screenbox_*.png; do
  name=$(basename "$img" .png)
  if [ ! -s "$OUT/$name.md" ]; then
    echo ">>> Analyzing $name ..."
    z-ai vision -p "$PROMPT" -i "$img" -o "$OUT/$name.json" 2>/dev/null
    # استخراج المحتوى من JSON
    python3 -c "
import json
try:
    with open('$OUT/$name.json') as f:
        d = json.load(f)
    content = d.get('content') or d.get('choices',[{}])[0].get('message',{}).get('content','') or str(d)
    with open('$OUT/$name.md','w') as f:
        f.write(content)
    print('  saved', len(content), 'chars')
except Exception as e:
    print('  ERROR:', e)
"
  else
    echo ">>> $name already analyzed (skip)"
  fi
done
echo "=== DONE. Files in $OUT: ==="
ls -la "$OUT"/*.md 2>/dev/null
