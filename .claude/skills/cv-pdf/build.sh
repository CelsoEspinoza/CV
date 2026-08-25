#!/usr/bin/env bash
# Builds the CV PDFs from their HTML sources and verifies each fits on one page.
# Usage:  ./build.sh [file.html ...]     (no arguments: cv.es.html and cv.en.html)
set -euo pipefail

# Repo root = two levels above .claude/skills/cv-pdf/
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

# --- locate Chrome ----------------------------------------------------------
CHROME=""
for c in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
  "$(command -v google-chrome || true)" \
  "$(command -v chromium || true)"; do
  [[ -n "$c" && -x "$c" ]] && { CHROME="$c"; break; }
done
[[ -z "$CHROME" ]] && { echo "error: no Chrome/Chromium/Edge found" >&2; exit 1; }

FILES=("$@")
[[ ${#FILES[@]} -eq 0 ]] && FILES=(cv.es.html cv.en.html)

# --- warn if the two language versions' CSS has drifted apart ---------------
if [[ -f cv.es.html && -f cv.en.html ]]; then
  python3 - <<'PY' || true
import re, sys
p = re.compile(r'<style>.*?</style>', re.S)
try:
    a = p.search(open('cv.es.html', encoding='utf-8').read()).group(0)
    b = p.search(open('cv.en.html', encoding='utf-8').read()).group(0)
except (AttributeError, FileNotFoundError):
    sys.exit(0)
if a != b:
    print("warning: CSS differs between cv.es.html and cv.en.html; the versions will look different.")
PY
fi

# --- build and verify -------------------------------------------------------
STATUS=0
for html in "${FILES[@]}"; do
  [[ -f "$html" ]] || { echo "error: $html not found" >&2; STATUS=1; continue; }

  # @page must use margin:0 — the print margin comes from the body padding.
  if ! grep -qE '@page[^}]*margin:\s*0\s*;' "$html"; then
    echo "warning: $html has no '@page { ... margin: 0 }'; margins will be doubled when printing." >&2
  fi

  pdf="${html%.html}.pdf"
  "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
            --print-to-pdf="$ROOT/$pdf" "file://$ROOT/$html" 2>/dev/null

  read -r pages size < <(python3 -c "
import re, sys
d = open('$pdf','rb').read()
print(len(re.findall(rb'/Type\s*/Page[^s]', d)), len(d)//1024)
")
  if [[ "$pages" -eq 1 ]]; then
    echo "ok   $pdf — 1 page, ${size} KB"
  else
    echo "WARN $pdf — $pages pages, ${size} KB (should be 1; see 'When it no longer fits' in SKILL.md)"
    STATUS=1
  fi
done

exit $STATUS
