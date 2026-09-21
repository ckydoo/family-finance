
"""Mhuri Money static balance checker (v2, interpolation-aware).
Usage: python3 tools/strip_check.py   (from repo root or app/)"""
import os, sys

def strip_v2(src):
    out = []
    stack = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        top = stack[-1] if stack else None
        if top is None:
            if c == '/' and i + 1 < n and src[i+1] == '/':
                j = src.find('\n', i)
                i = n if j == -1 else j
            elif c == '/' and i + 1 < n and src[i+1] == '*':
                j = src.find('*/', i + 2)
                i = n if j == -1 else j + 2
            elif c == "'":
                stack.append(['sq']); i += 1
            elif c == '"':
                stack.append(['dq']); i += 1
            else:
                out.append(c); i += 1
        else:
            kind = top[0]
            if kind in ('sq', 'dq'):
                q = "'" if kind == 'sq' else '"'
                if c == '\\':
                    i += 2; continue
                if c == '$' and i + 1 < n and src[i+1] == '{':
                    stack.append(['interp', 1]); i += 2; continue
                if c == q:
                    stack.pop()
                i += 1
            elif kind == 'interp':
                if c == '{':
                    top[1] += 1; i += 1
                elif c == '}':
                    if top[1] == 1: stack.pop()
                    else: top[1] -= 1
                    i += 1
                elif c == "'":
                    stack.append(['sq']); i += 1
                elif c == '"':
                    stack.append(['dq']); i += 1
                elif c == '\\':
                    i += 2
                else:
                    i += 1
    return ''.join(out)

roots = sys.argv[1:] or ['.']
ok = True; count = 0
for root in roots:
    for base, _, files in os.walk(root):
        if any(x in base for x in ['.git', 'build', '.dart_tool']): continue
        for f in files:
            if not f.endswith('.dart'): continue
            p = os.path.join(base, f); count += 1
            st = strip_v2(open(p, encoding='utf-8').read())
            for o, c, name in [('{','}','brace'), ('(',')','paren'), ('[',']','bracket')]:
                if st.count(o) != st.count(c):
                    print(f'UNBALANCED {name} in {p}'); ok = False
print(f'{count} files: {"ALL BALANCED" if ok else "FAIL"}')
