import re, json, os, sys
log = open(sys.argv[1]).read().splitlines()
summary = json.load(open(sys.argv[2]))
outdir = sys.argv[3]
os.makedirs(outdir, exist_ok=True)
hdr = re.compile(r'^\d+:\d+ \+\d+ (?:~\d+ )?-\d+: (.*?)( \[E\])?$')
# find start line for each (name) -> the FIRST header line with that name w/o [E]
starts = {}
ends = {}
for i, l in enumerate(log):
    m = hdr.match(l)
    if not m: continue
    name = m.group(1)
    name = name.replace('/Users/roliv/flutter/packages/flutter/test/material/selectable_text_test.dart: ', '')
    if m.group(2):
        ends[name] = i
    else:
        starts.setdefault(name, i)
names_by_idx = {e['name']: e['idx'] for e in summary if e.get('idx')}
def find_idx(fullname):
    base = re.sub(r' \(variant: .*\)$', '', fullname)
    if base in names_by_idx: return names_by_idx[base], base
    # strip group prefix
    for n, i in names_by_idx.items():
        if base.endswith(n): return i, n
    return None, base
result = []
for name, endi in ends.items():
    s = starts.get(name)
    if s is None:
        print("NO START for", name); continue
    body = log[s+1:endi]
    idx, base = find_idx(name)
    var = re.search(r'\(variant: (.*)\)$', name)
    var = var.group(1) if var else ''
    fn = f"{idx:03d}" if idx else "UNK"
    safe = re.sub(r'[^A-Za-z0-9.]+', '_', var)
    path = os.path.join(outdir, f"{fn}{'_' + safe if safe else ''}.txt")
    with open(path, 'w') as f:
        f.write(f"### FAILURE: {name}\n### test idx {idx}\n\n")
        f.write('\n'.join(body) + '\n')
    result.append({'idx': idx, 'name': base, 'variant': var, 'file': os.path.basename(path), 'lines': len(body)})
result.sort(key=lambda r: (r['idx'] or 999, r['variant']))
json.dump(result, open(os.path.join(outdir, 'failures.json'), 'w'), indent=1)
uniq = sorted(set(r['idx'] for r in result))
print("unique failing test indices:", len(uniq))
print(uniq)
for r in result: print(r['idx'], r['file'], r['lines'], r['name'], r['variant'])
