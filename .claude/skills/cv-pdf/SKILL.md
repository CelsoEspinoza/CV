---
name: cv-pdf
description: Regenerates the CV PDFs (cv.es.pdf, cv.en.pdf) from their HTML sources and verifies each one still fits on a single page. Use after editing cv.es.html or cv.en.html, or when asked to build/update/export the CV PDF, or when the CV overflows onto a second page.
---

# Building the CV PDFs

The PDFs are produced by printing the HTML sources with headless Chrome. The hard design rule:
**each CV must fit on exactly one page**, and **font sizes are never changed**.

## Normal usage

```bash
.claude/skills/cv-pdf/build.sh              # both languages
.claude/skills/cv-pdf/build.sh cv.es.html   # a single file
```

It writes `cv.es.pdf` and `cv.en.pdf` next to their HTML sources, reports page count and file
size, and **exits with status 1 if any PDF runs longer than one page**. It never touches
`CV.pdf` (a legacy file: an older, shorter version of the CV).

## How this is wired up

| File | Role |
|---|---|
| `cv.es.html` | Spanish CV (source) |
| `cv.en.html` | English CV (source) |
| `cv.es.pdf` / `cv.en.pdf` | Generated output — never edit by hand |
| `CV.pdf` | Legacy file, outside this workflow |

Both HTML files are self-contained (inline CSS, no external assets) and carry
`body contenteditable="true"`, so they can be edited by opening them in a browser.

`index.html` links to `cv.en.pdf` and `cv.es.pdf` from three places (nav, hero, contact
section). If you rename an output file, update those links too.

### Two rules that must hold

**1. `@page` must use `margin: 0`.** The print margin comes from the `body` padding
(`0.34in 0.6in`). If `@page` also declares a margin, the two add up and the text column
shrinks from 7.3in to 6.1in, which pushes content onto a second page. `build.sh` warns
when it detects this.

**2. The CSS must stay identical across both languages.** The two versions share their
entire `<style>` block so they look symmetrical. When adjusting spacing, apply the same
change to both files. `build.sh` warns if they drift apart. To resync:

```bash
python3 - <<'PY'
import re
p = re.compile(r'<style>.*?</style>', re.S)
es = open('cv.es.html', encoding='utf-8').read()
en = open('cv.en.html', encoding='utf-8').read()
open('cv.en.html','w',encoding='utf-8').write(p.sub(lambda m: p.search(es).group(0), en, count=1))
PY
```

## When it no longer fits on one page

This happens as content grows (a new role, a longer bullet). Work in this order:

### 1. Measure the overflow

`scrollHeight` **lies** when the last element has a bottom margin: it does not count it.
Always measure from the real bottom edge of the last child plus the body's `padding-bottom`:

```bash
python3 -m http.server 8777 >/dev/null 2>&1 &   # file:// is blocked in Playwright
```

Then navigate to `http://localhost:8777/cv.es.html` and evaluate:

```js
() => {
  const b = document.body, last = b.lastElementChild;
  const pad = parseFloat(getComputedStyle(b).paddingBottom);
  const used = last.getBoundingClientRect().bottom + window.scrollY + pad;
  return { usedIn: +(used/96).toFixed(2), headroomIn: +((11*96 - used)/96).toFixed(2) };
}
```

96px = 1in. A Letter page is 11in tall. Aim for **≤ 10.8in** to keep some headroom.
Remember to `pkill -f "http.server 8777"` when done.

### 2. Adjust spacing, never font size

Current values and how far each can be tightened before the layout looks cramped:

| Rule | Property | Current | Suggested floor |
|---|---|---|---|
| `body` | `padding` | `0.34in 0.6in` | `0.3in` vertical (below that, printer-margin risk) |
| `body` | `line-height` | 1.32 | 1.28 |
| `hr` | `margin` | `3px 0 6px` | `2px 0 4px` |
| `h2.section` | `margin` | `3px 0 4px` | `2px 0 3px` |
| `p.summary` | `line-height` | 1.34 | 1.3 |
| `.job` | `margin-bottom` | 4px | 3px |
| `.job-meta` | `margin` | `0 0 2px` | `0 0 1px` |
| `ul.bullets li` | `line-height` | 1.25 | 1.22 |
| `ul.bullets li` | `margin-bottom` | 1px | 0 |
| `table.skills td` | `padding` | `1px 0` | 0 |
| `.edu-meta` | `margin` | `0 0 4px` | `0 0 2px` |

Bullets are the highest-yield lever: there are ~26 lines, so 0.03 of `line-height` buys
roughly 0.1in. **Do not change `font-size` in any rule** — avoiding that is the whole point
of this approach.

If you exhaust the floors and it still does not fit, the content is genuinely too long: tell
the user and propose shortening the longest bullet (the Yape Buses one runs to 3 lines)
rather than compressing further.

### 3. Verify against the PDF, not the measurement

Print layout differs from screen layout. The only valid proof is `build.sh`, which counts
the pages of the generated PDF.

## Notes

- Spanish runs ~0.2in longer than English for the same content; if Spanish fits, English will too.
- Helvetica Neue, Helvetica and Arial are metrically compatible, so the PDF will not overflow when regenerated on Windows or Linux.
- Chrome's output is deterministic except for the embedded `CreationDate`/`ModDate`, so a rebuild with no source change alters only 4 bytes.
- When printing by hand with `Cmd+P`: margins set to **Default** and **uncheck** headers and footers.
