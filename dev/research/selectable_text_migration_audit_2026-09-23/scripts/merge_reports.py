import re, json, glob, os, sys
from collections import defaultdict, Counter
S='/private/tmp/claude-501/-Users-roliv-flutter/727bb496-578a-49a2-b6c9-df33a85675f3/scratchpad'
rows={r['idx']:r for r in json.load(open(f'{S}/status_table.json'))}
FIELDS=['status_at_head','change_status','part_a_verdict','part_a_details','part_a_evidence','part_b_classification','part_b_root_cause','part_b_surface_fix','gap_ids','gap_notes','confidence']
tests={}
for path in sorted(glob.glob(f'{S}/reports/*.md')):
    group=os.path.basename(path)[:-3]
    txt=open(path).read()
    # split on '## Test'
    parts=re.split(r'(?m)^## Test ', txt)
    for p in parts[1:]:
        m=re.match(r'(\d+)\s*[—-]+\s*(.*)', p)
        if not m: continue
        idx=int(m.group(1)); name=m.group(2).strip()
        body=p[m.end():]
        # stop at next '## ' header (group summary)
        body=re.split(r'(?m)^## ', body)[0]
        rec={'idx':idx,'name':name,'group':group}
        # parse fields: lines starting with '- field:' possibly multi-line until next '- field:'
        cur=None; buf=[]
        for line in body.splitlines():
            fm=re.match(r'^\s*[-*]\s*\*{0,2}(%s)\*{0,2}\s*:\s*(.*)$'%'|'.join(FIELDS), line)
            if fm:
                if cur: rec[cur]='\n'.join(buf).strip()
                cur=fm.group(1); buf=[fm.group(2)]
            elif cur:
                buf.append(line)
        if cur: rec[cur]='\n'.join(buf).strip()
        tests[idx]=rec
missing=[i for i in rows if i not in tests and rows[i]['change']!='UNCHANGED' or (i in rows and rows[i]['head']=='FAILING' and i not in tests)]
print('parsed tests:',len(tests),'missing:',sorted(set(missing)))
def norm_verdict(v):
    v=(v or '').upper()
    for k in ['FAKE FIX','WARRANTED','MIXED','COSMETIC','PARTIAL','N/A']:
        if v.startswith(k): return k
    return v.split('\n')[0][:20]
def norm_b(v):
    v=(v or '').upper()
    for k in ['SURFACE','GAP','MIXED','N/A']:
        if v.startswith(k): return k
    return v.split('\n')[0][:20]
va=Counter(); vb=Counter(); gaps=defaultdict(list)
for i,t in sorted(tests.items()):
    t['A']=norm_verdict(t.get('part_a_verdict')); t['B']=norm_b(t.get('part_b_classification'))
    va[t['A']]+=1; vb[t['B']]+=1
    for g in re.findall(r'G-[A-Z0-9-]+', t.get('gap_ids','') or ''):
        gaps[g].append(i)
print('Part A verdicts:',dict(va)); print('Part B classes:',dict(vb))
print('\nGAP GROUPS:')
for g,ids in sorted(gaps.items(), key=lambda kv:-len(kv[1])):
    print(f"  {g}: {len(ids)} tests -> {ids}")
print()
print(f"{'idx':>4} {'head':<8} {'chg':<9} {'A':<10} {'B':<8} gaps | name")
for i,t in sorted(tests.items()):
    r=rows[i]
    print(f"{i:>4} {r['head']:<8} {r['change']:<9} {t['A']:<10} {t['B']:<8} {','.join(re.findall(r'G-[A-Z0-9-]+', t.get('gap_ids','') or ''))} | {r['name'][:70]}")
json.dump({'tests':tests,'gaps':gaps}, open(f'{S}/merged.json','w'), indent=1)
