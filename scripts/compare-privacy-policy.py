#!/usr/bin/env python3
"""Check the iOS privacy policy matches its published copy, word-for-word.

App Review is given a hosted URL for the policy and compares it against what the
app shows. CLAUDE.md requires the two to be identical; this is the check to run
before submitting, and after ANY edit to either side.

    python3 scripts/compare-privacy-policy.py [path-to-privacy-ios.html]

Defaults to ../memory-journal-website/privacy-ios.html, the working copy of
https://www.keepsakejournal.app/privacy-ios. Exits non-zero on a mismatch and
prints a diff. Navigation chrome that only exists on one side (the web page's
back links, the sheet's Done button) is ignored; everything else must match.
"""

import re, html, difflib, sys
from pathlib import Path

# Navigation/chrome that exists on one surface but not the other.
SKIP = {'← keepsake', '← Back to keepsake', 'Privacy Policy', 'keepsake for iOS',
        'privacy policy', 'Done'}

def web_blocks(path):
    raw = open(path).read()
    body = re.split(r'<article[^>]*>', raw, maxsplit=1)[1].split('</article>', 1)[0]
    body = re.sub(r'<!--.*?-->', ' ', body, flags=re.S)
    body = re.sub(r'</(p|h1|h2|li|a)>', '\x1e', body)   # block boundaries first
    body = re.sub(r'<[^>]+>', ' ', body)
    body = html.unescape(body)
    return [re.sub(r'\s+', ' ', b).strip() for b in body.split('\x1e')]

def app_blocks(path):
    src = open(path).read()
    src = src.split('var body: some View', 1)[1].split('/// One titled paragraph', 1)[0]
    out = []
    for triple, single in re.findall(r'"""(.*?)"""|"((?:[^"\\]|\\.)*)"', src, flags=re.S):
        text = (triple or single).replace('\\"', '"')
        out.extend(text.split('\n\n'))          # blank line = new paragraph
    return [re.sub(r'\s+', ' ', b).strip() for b in out]

def normalise(blocks):
    out = []
    for b in blocks:
        if not b or b in SKIP:
            continue
        if '•' in b:
            out.extend(p.strip() for p in b.split('•') if p.strip())
        else:
            out.append(b)
    return out

REPO = Path(__file__).resolve().parent.parent
DEFAULT_WEB = REPO.parent / 'memory-journal-website' / 'privacy-ios.html'

web_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_WEB
if not web_path.exists():
    sys.exit(f"Can't find the hosted copy at {web_path}. Pass its path as an argument.")

app = normalise(app_blocks(REPO / 'MemoryJournal' / 'Onboarding' / 'PrivacyPolicyView.swift'))
web = normalise(web_blocks(web_path))

diff = list(difflib.unified_diff(app, web, 'in-app', 'website', lineterm='', n=0))
if diff:
    print("MISMATCH:\n" + '\n'.join(diff))
    sys.exit(1)
print(f"IDENTICAL — {len(app)} text blocks match word-for-word ({web_path})")
