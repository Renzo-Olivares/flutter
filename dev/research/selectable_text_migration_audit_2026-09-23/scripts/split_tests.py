import re, sys, json, os, difflib

def strip_for_scan(src):
    """Return a same-length string where string literals and comments are blanked (keeping newlines), so paren matching is safe."""
    out = list(src)
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            j = src.find('\n', i)
            if j == -1: j = n
            for k in range(i, j): out[k] = ' '
            i = j
        elif src.startswith('/*', i):
            j = src.find('*/', i+2)
            if j == -1: j = n
            else: j += 2
            for k in range(i, j):
                if src[k] != '\n': out[k] = ' '
            i = j
        elif c in ('"', "'"):
            # handle triple quotes
            if src.startswith(c*3, i):
                j = src.find(c*3, i+3)
                if j == -1: j = n
                else: j += 3
            else:
                j = i+1
                while j < n:
                    if src[j] == '\\': j += 2; continue
                    if src[j] == c: j += 1; break
                    if src[j] == '\n': break
                    j += 1
            for k in range(i+1, min(j, n)-1):
                if src[k] != '\n': out[k] = 'x'
            i = j
        else:
            i += 1
    return ''.join(out)

def extract_tests(path):
    src = open(path).read()
    scan = strip_for_scan(src)
    tests = []
    # find 'testWidgets(' or 'test(' at statement start
    for m in re.finditer(r'(?m)^[ \t]*(testWidgets|test)\(', scan):
        start = m.start()
        # find matching paren
        i = m.end()-1
        depth = 0
        j = i
        while j < len(scan):
            if scan[j] == '(': depth += 1
            elif scan[j] == ')':
                depth -= 1
                if depth == 0: break
            j += 1
        # include trailing ';'
        end = j+1
        while end < len(src) and src[end] in ' \t': end += 1
        if end < len(src) and src[end] == ';': end += 1
        block = src[start:end]
        # extract name: first string literal after '('
        nm = re.search(r"""^[ \t]*(?:testWidgets|test)\(\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")""", block, re.S)
        name = (nm.group(1) or nm.group(2)) if nm else '<unnamed>'
        # handle adjacent string concatenation like 'a' 'b'
        # count line numbers
        line_start = src.count('\n', 0, start) + 1
        line_end = src.count('\n', 0, end) + 1
        tests.append({'name': name, 'start': line_start, 'end': line_end, 'block': block})
    # determine enclosing group names via a simple scan
    return tests

base = extract_tests(sys.argv[1])
head = extract_tests(sys.argv[2])
outdir = sys.argv[3]
os.makedirs(outdir, exist_ok=True)

def key(t): return t['name']
bmap = {}
for t in base:
    bmap.setdefault(key(t), []).append(t)
hmap = {}
for t in head:
    hmap.setdefault(key(t), []).append(t)

def norm(block):
    return '\n'.join(l.rstrip() for l in block.strip().splitlines())

summary = []
idx = 0
for t in head:
    idx += 1
    k = key(t)
    b = bmap.get(k)
    entry = {'idx': idx, 'name': k, 'head_lines': f"{t['start']}-{t['end']}"}
    if not b:
        entry['status'] = 'ADDED'
    else:
        bt = b[0]
        entry['base_lines'] = f"{bt['start']}-{bt['end']}"
        if norm(bt['block']) == norm(t['block']):
            entry['status'] = 'UNCHANGED'
        else:
            entry['status'] = 'MODIFIED'
            diff = difflib.unified_diff(bt['block'].splitlines(), t['block'].splitlines(), 'base', 'head', lineterm='', n=3)
            entry['diff_lines'] = sum(1 for l in diff if (l.startswith('+') or l.startswith('-')) and not l.startswith('+++') and not l.startswith('---'))
            fn = os.path.join(outdir, f"{idx:03d}.diff")
            with open(fn, 'w') as f:
                f.write(f"### TEST {idx}: {k}\n### base lines {entry['base_lines']} | head lines {entry['head_lines']}\n")
                f.write('\n'.join(difflib.unified_diff(bt['block'].splitlines(), t['block'].splitlines(), 'base', 'head', lineterm='', n=4)))
                f.write('\n')
            with open(os.path.join(outdir, f"{idx:03d}.base.dart"), 'w') as f: f.write(bt['block'])
            with open(os.path.join(outdir, f"{idx:03d}.head.dart"), 'w') as f: f.write(t['block'])
    summary.append(entry)
for k, b in bmap.items():
    if k not in hmap:
        summary.append({'idx': None, 'name': k, 'base_lines': f"{b[0]['start']}-{b[0]['end']}", 'status': 'REMOVED'})

json.dump(summary, open(os.path.join(outdir, 'summary.json'), 'w'), indent=1)
from collections import Counter
print(Counter(e['status'] for e in summary))
for e in summary:
    print(f"{str(e.get('idx')):>4} {e['status']:<9} {e.get('diff_lines',''):>4} {e['name']}")
